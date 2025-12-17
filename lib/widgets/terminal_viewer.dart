import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import 'package:xterm/xterm.dart';
import 'package:pty/pty.dart';
import 'package:file_picker/file_picker.dart';
import '../services/session_manager.dart';

/// Widget that displays an interactive terminal connected to a Kubernetes pod container
class TerminalViewer extends StatefulWidget {
  final Session session;

  const TerminalViewer({
    super.key,
    required this.session,
  });

  @override
  State<TerminalViewer> createState() => _TerminalViewerState();
}

class _TerminalViewerState extends State<TerminalViewer> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  late PseudoTerminal? _pty;
  bool _isLoading = true;
  String? _error;
  String? _resolvedContainerName;
  String _currentDirectory = '~'; // Track current directory from PTY output
  final StringBuffer _outputBuffer = StringBuffer(); // Buffer to track recent output
  bool _isTerminalReady = false; // Track if terminal is ready for input

  @override
  void initState() {
    super.initState();

    // Reuse existing terminal, PTY, and controller from session if available
    if (widget.session.terminal != null &&
        widget.session.pty != null &&
        widget.session.terminalController != null) {
      _terminal = widget.session.terminal!;
      _pty = widget.session.pty;
      _terminalController = widget.session.terminalController!;
      _isLoading = false;
      _isTerminalReady = true; // Already initialized, ready for input

      // Reconnect handlers even when reusing terminal
      _terminal.onOutput = (data) {
        // Only send input if terminal is ready
        if (_isTerminalReady) {
          _pty?.write(data);
        }
      };
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Resize the PTY when terminal is resized
        _pty?.resize(width, height);
      };

      // NOTE: Don't recreate the PTY output listener - it's already listening
      // The StreamSubscription is stored in the session and continues running
    } else {
      // Create new terminal, controller, and PTY
      _terminalController = TerminalController();
      _terminal = Terminal(
        maxLines: 10000,
      );
      _terminal.onOutput = (data) {
        // Only send input if terminal is ready
        if (_isTerminalReady) {
          _pty?.write(data);
        }
      };
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Resize the PTY when terminal is resized
        _pty?.resize(width, height);
      };

      // Store in session for reuse
      widget.session.terminal = _terminal;
      widget.session.terminalController = _terminalController;

      _startTerminalSession();
    }
  }

  @override
  void dispose() {
    // Don't kill PTY here - it's managed by the session
    super.dispose();
  }

  Future<void> _startTerminalSession() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Resolve container name if not provided
      String? containerName = widget.session.containerName;
      if (containerName == null) {
        final coreV1Api = widget.session.kubernetesClient.client.getCoreV1Api();
        final podResponse = await coreV1Api.readNamespacedPod(
          name: widget.session.podName,
          namespace: widget.session.namespace,
        );
        final containers = podResponse.data?.spec?.containers ?? [];
        if (containers.isNotEmpty) {
          containerName = containers.first.name;
        }
      }

      if (containerName == null) {
        setState(() {
          _error = 'No container found in pod';
          _isLoading = false;
        });
        return;
      }

      _resolvedContainerName = containerName;

      // Start kubectl exec with a real PTY for full terminal support
      _pty = PseudoTerminal.start(
        'kubectl',
        [
          'exec',
          '-it',
          '-n',
          widget.session.namespace,
          widget.session.podName,
          '-c',
          containerName,
          '--',
          '/bin/bash',
        ],
        environment: {
          'TERM': 'xterm-256color',
        },
      );

      // Store PTY in session for reuse
      widget.session.pty = _pty;

      setState(() {
        _isLoading = false;
      });

      // Listen to PTY output and write to terminal
      // Store the subscription so it persists across minimize/restore
      // Note: We don't check 'mounted' here because the terminal object persists
      widget.session.ptyOutputSubscription = _pty!.out.listen(
        (data) {
          _terminal.write(data);

          // Always buffer output
          _outputBuffer.write(data);

          // Keep buffer size manageable (last 500 characters)
          if (_outputBuffer.length > 500) {
            final content = _outputBuffer.toString();
            _outputBuffer.clear();
            _outputBuffer.write(content.substring(content.length - 500));
          }

          // Only try to extract directory if we see a prompt character
          // This avoids expensive regex on every output chunk
          if (data.contains('\$') || data.contains('#')) {
            // Try to extract current directory from the buffered output
            _extractCurrentDirectory(_outputBuffer.toString());

            // Mark terminal as ready when we see the first prompt
            if (!_isTerminalReady) {
              setState(() {
                _isTerminalReady = true;
              });
            }
          }
        },
        onError: (error) {
          _terminal.write('\r\n[Error: $error]\r\n');
        },
        onDone: () {
          _terminal.write('\r\n[Terminal session ended]\r\n');
        },
      );

      // Set initial terminal size
      _pty!.resize(_terminal.viewWidth, _terminal.viewHeight);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Extract current directory from PTY output
  /// Looks for common bash prompt patterns like: user@host:/path/to/dir$
  void _extractCurrentDirectory(String data) {
    // Common patterns for bash prompts that include the current directory:
    // 1. user@host:/path/to/dir$ or user@host:/path/to/dir#
    // 2. /path/to/dir$ or /path/to/dir#
    // 3. [user@host /path/to/dir]$ or [user@host /path/to/dir]#

    // Pattern: anything:/path$ or anything:/path# (followed by space or end of string)
    // Use allMatches to find all occurrences and take the last one
    final pattern1 = RegExp(r':([~/][^\s\$#\r\n:]*?)[\$#](?:\s|$)');
    final matches1 = pattern1.allMatches(data);
    if (matches1.isNotEmpty) {
      final lastMatch = matches1.last;
      final dir = lastMatch.group(1);
      if (dir != null && dir.isNotEmpty) {
        _currentDirectory = dir;
        return;
      }
    }

    // Pattern: [anything /path]$ or [anything /path]#
    final pattern2 = RegExp(r'\s([~/][^\s\$#\]]*?)\][\$#]');
    final matches2 = pattern2.allMatches(data);
    if (matches2.isNotEmpty) {
      final lastMatch = matches2.last;
      final dir = lastMatch.group(1);
      if (dir != null && dir.isNotEmpty) {
        _currentDirectory = dir;
        return;
      }
    }
  }

  /// Upload a file to the pod's current directory
  Future<void> _uploadFile() async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        _showErrorSnackbar('Could not access file path');
        return;
      }

      // Build the remote path using the tracked current directory
      final remotePath = _currentDirectory.endsWith('/')
          ? '$_currentDirectory${file.name}'
          : '$_currentDirectory/${file.name}';

      // Show progress indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Uploading to $_currentDirectory...'),
              ),
            ],
          ),
          duration: const Duration(hours: 1), // Will be dismissed manually
        ),
      );

      // Use kubectl cp to upload the file to the current directory
      final process = await Process.run(
        'kubectl',
        [
          'cp',
          file.path!,
          '${widget.session.namespace}/${widget.session.podName}:$remotePath',
          '-c',
          _resolvedContainerName ?? widget.session.containerName ?? '',
        ],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (process.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${file.name} successfully')),
        );
      } else {
        _showErrorSnackbar('Upload failed: ${process.stderr}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackbar('Upload error: $e');
      }
    }
  }

  /// Get list of files in the current directory
  Future<List<String>> _listFiles() async {
    try {
      final process = await Process.run(
        'kubectl',
        [
          'exec',
          '-n',
          widget.session.namespace,
          widget.session.podName,
          '-c',
          _resolvedContainerName ?? widget.session.containerName ?? '',
          '--',
          'ls',
          '-1', // One file per line
          '-A', // Include hidden files
          _currentDirectory,
        ],
      );

      if (process.exitCode == 0) {
        final output = process.stdout.toString().trim();
        if (output.isEmpty) return [];
        return output.split('\n').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }

  /// Download files from the pod
  Future<void> _downloadFile() async {
    // Show loading dialog while fetching file list
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading files...'),
              ],
            ),
          ),
        ),
      ),
    );

    final files = await _listFiles();

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (files.isEmpty) {
      _showErrorSnackbar('No files found in $_currentDirectory');
      return;
    }

    // Show file selection dialog
    final selectedFiles = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FileSelectionDialog(
        files: files,
        currentDirectory: _currentDirectory,
      ),
    );

    if (selectedFiles == null || selectedFiles.isEmpty) return;

    try {
      // Pick a directory to save the files
      final outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select directory to save files',
      );

      if (outputDir == null) return;

      // Check for existing files and directories
      final existingFiles = <String>[];
      for (final fileName in selectedFiles) {
        final localPath = '$outputDir/$fileName';
        if (File(localPath).existsSync() || Directory(localPath).existsSync()) {
          existingFiles.add(fileName);
        }
      }

      // Show warning if files exist
      if (existingFiles.isNotEmpty) {
        if (!mounted) return;
        final shouldOverwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Items Already Exist'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existingFiles.length == 1
                      ? 'The following item already exists and will be overwritten:'
                      : 'The following ${existingFiles.length} items already exist and will be overwritten:',
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: existingFiles.map((file) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $file',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Overwrite'),
              ),
            ],
          ),
        );

        if (shouldOverwrite != true) return;
      }

      // Show progress indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Downloading ${selectedFiles.length} file(s)...'),
              ),
            ],
          ),
          duration: const Duration(hours: 1), // Will be dismissed manually
        ),
      );

      int successCount = 0;
      int failCount = 0;

      // Download each selected file
      for (final fileName in selectedFiles) {
        final remotePath = _currentDirectory.endsWith('/')
            ? '$_currentDirectory$fileName'
            : '$_currentDirectory/$fileName';
        final localPath = '$outputDir/$fileName';

        final process = await Process.run(
          'kubectl',
          [
            'cp',
            '${widget.session.namespace}/${widget.session.podName}:$remotePath',
            localPath,
            '-c',
            _resolvedContainerName ?? widget.session.containerName ?? '',
          ],
        );

        if (process.exitCode == 0) {
          successCount++;
        } else {
          failCount++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $successCount file(s) to $outputDir')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $successCount file(s), $failCount failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackbar('Download error: $e');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Terminal: ${widget.session.podName}${_resolvedContainerName != null ? '/$_resolvedContainerName' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Upload button
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  iconSize: 20,
                  tooltip: 'Upload file to current directory',
                  onPressed: _isLoading || _error != null ? null : _uploadFile,
                ),
                // Download button
                IconButton(
                  icon: const Icon(Icons.download),
                  iconSize: 20,
                  tooltip: 'Download file from container',
                  onPressed: _isLoading || _error != null ? null : _downloadFile,
                ),
              ],
            ),
          ),
          // Terminal content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error starting terminal',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          TerminalView(
                            _terminal,
                            key: ValueKey('terminal-${widget.session.id}'),
                            controller: _terminalController,
                            autofocus: true,
                            backgroundOpacity: 1.0,
                            padding: const EdgeInsets.all(8),
                            textStyle: const TerminalStyle(
                              fontFamily: 'Courier New',
                              fontSize: 14,
                            ),
                          ),
                          // Show overlay when terminal is not ready
                          if (!_isTerminalReady)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        'Initializing terminal...',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for selecting files to download
class _FileSelectionDialog extends StatefulWidget {
  final List<String> files;
  final String currentDirectory;

  const _FileSelectionDialog({
    required this.files,
    required this.currentDirectory,
  });

  @override
  State<_FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<_FileSelectionDialog> {
  final Set<String> _selectedFiles = {};
  bool _selectAll = false;

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedFiles.addAll(widget.files);
      } else {
        _selectedFiles.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Download Files'),
                const SizedBox(height: 4),
                Text(
                  widget.currentDirectory,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            // Select all checkbox
            CheckboxListTile(
              title: Text(
                'Select All (${widget.files.length} files)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _selectAll,
              onChanged: (_) => _toggleSelectAll(),
              dense: true,
            ),
            const Divider(),
            // File list
            Expanded(
              child: ListView.builder(
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  final isSelected = _selectedFiles.contains(file);

                  return CheckboxListTile(
                    title: Text(file),
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedFiles.add(file);
                        } else {
                          _selectedFiles.remove(file);
                        }
                        _selectAll = _selectedFiles.length == widget.files.length;
                      });
                    },
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedFiles.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedFiles.toList()),
          child: Text('Download ${_selectedFiles.length} file(s)'),
        ),
      ],
    );
  }
}
