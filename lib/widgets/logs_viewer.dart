import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:k8s/k8s.dart';
import '../services/auth_refresh_manager.dart';

/// Widget that displays streaming logs from a Kubernetes job container
class LogsViewer extends StatefulWidget {
  final Kubernetes kubernetesClient;
  final String namespace;
  final String jobName;
  final String? containerName;
  final bool isPodLog; // If true, jobName is actually a pod name

  const LogsViewer({
    super.key,
    required this.kubernetesClient,
    required this.namespace,
    required this.jobName,
    this.containerName,
    this.isPodLog = false,
  });

  @override
  State<LogsViewer> createState() => _LogsViewerState();
}

class _LogsViewerState extends State<LogsViewer> {
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _logSubscription;
  bool _isLoading = true;
  String? _error;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _startWatchingLogs();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startWatchingLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      String podName;
      String? containerName = widget.containerName;

      if (widget.isPodLog) {
        // Direct pod log - jobName is actually the pod name
        podName = widget.jobName;

        // If no container name specified, we'll let kubectl use the default
        if (containerName == null) {
          final coreV1Api = widget.kubernetesClient.client.getCoreV1Api();
          final podResponse = await coreV1Api.readNamespacedPod(
            name: podName,
            namespace: widget.namespace,
          );
          final containers = podResponse.data?.spec?.containers ?? [];
          if (containers.isNotEmpty) {
            containerName = containers.first.name;
          }
        }
      } else {
        // Job log - need to find the pod by job-name label
        final coreV1Api = widget.kubernetesClient.client.getCoreV1Api();

        final podList = await coreV1Api.listNamespacedPod(
          namespace: widget.namespace,
          labelSelector: 'job-name=${widget.jobName}',
        );

        if (podList.data?.items.isEmpty ?? true) {
          setState(() {
            _error = 'No pods found for job ${widget.jobName}';
            _isLoading = false;
          });
          return;
        }

        final pod = podList.data!.items.first;
        final foundPodName = pod.metadata?.name;

        if (foundPodName == null) {
          setState(() {
            _error = 'Pod name not found';
            _isLoading = false;
          });
          return;
        }

        podName = foundPodName;

        // Determine container name
        if (containerName == null) {
          final containers = pod.spec?.containers ?? [];
          if (containers.isNotEmpty) {
            containerName = containers.first.name;
          }
        }
      }

      if (containerName == null) {
        setState(() {
          _error = 'No container found in pod';
          _isLoading = false;
        });
        return;
      }

      // Start streaming logs
      _logSubscription = _streamLogs(podName, containerName).listen(
        (line) {
          if (mounted) {
            setState(() {
              _logLines.add(line);
              _isLoading = false;
            });

            // Auto-scroll to bottom if enabled
            if (_autoScroll && _scrollController.hasClients) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error starting logs: $e');

      // Check if this is a 401 error (expired token) and trigger refresh
      final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
      if (wasAuthError) {
        // Token refresh was triggered, don't show error to user
        // The logs will be retried when the client is refreshed
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Stream<String> _streamLogs(String podName, String containerName) async* {
    // Use kubectl to tail logs (simpler than implementing the streaming API)
    final process = await Process.start(
      'kubectl',
      [
        'logs',
        '-n',
        widget.namespace,
        podName,
        '-c',
        containerName,
        '--tail=10',
        '--follow',
      ],
    );

    await for (final line in process.stdout.transform(utf8.decoder)) {
      final lines = line.split('\n');
      for (final l in lines) {
        if (l.isNotEmpty) {
          yield l;
        }
      }
    }
  }

  void _copyAllLogs() {
    final allLogs = _logLines.join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  Icons.article_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Logs: ${widget.jobName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const Spacer(),
                // Auto-scroll toggle
                IconButton(
                  icon: Icon(
                    _autoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                    size: 18,
                  ),
                  tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                  color: _autoScroll ? Theme.of(context).colorScheme.primary : null,
                  onPressed: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                ),
                // Copy button
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy all logs',
                  onPressed: _logLines.isEmpty ? null : _copyAllLogs,
                ),
              ],
            ),
          ),
          // Logs content
          Expanded(
            child: _isLoading && _logLines.isEmpty
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
                                'Error loading logs',
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
                    : _logLines.isEmpty
                        ? Center(
                            child: Text(
                              'No logs available',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          )
                        : SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SelectableText(
                                _logLines.join('\n'),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

