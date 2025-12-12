import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import 'package:xterm/xterm.dart';
import 'package:pty/pty.dart';
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

      // Reconnect handlers even when reusing terminal
      _terminal.onOutput = (data) {
        // Send user input to the PTY
        _pty?.write(data);
      };
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Resize the PTY when terminal is resized
        _pty?.resize(height, width);
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
        // Send user input to the PTY
        _pty?.write(data);
      };
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Resize the PTY when terminal is resized
        _pty?.resize(height, width);
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
          '/bin/sh',
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
        },
        onError: (error) {
          _terminal.write('\r\n[Error: $error]\r\n');
        },
        onDone: () {
          _terminal.write('\r\n[Terminal session ended]\r\n');
        },
      );

      // Set initial terminal size
      _pty!.resize(_terminal.viewHeight, _terminal.viewWidth);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
                Text(
                  'Terminal: ${widget.session.podName}${_resolvedContainerName != null ? '/$_resolvedContainerName' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
                    : TerminalView(
                        _terminal,
                        key: ValueKey('terminal-${widget.session.id}'),
                        controller: _terminalController,
                        autofocus: true,
                        backgroundOpacity: 1.0,
                        padding: const EdgeInsets.all(8),
                      ),
          ),
        ],
      ),
    );
  }
}

