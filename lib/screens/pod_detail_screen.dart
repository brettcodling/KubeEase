import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:k8s/k8s.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pods/pod_service.dart';
import '../services/pods/pod_metrics_service.dart';
import '../services/session_manager.dart';
import '../services/port_forward_manager.dart';
import '../models/pod_event.dart';
import '../models/pod_metrics.dart';

/// Screen that displays detailed information about a Kubernetes Pod
class PodDetailScreen extends StatefulWidget {
  final String podName;
  final String namespace;
  final Kubernetes kubernetesClient;

  const PodDetailScreen({
    super.key,
    required this.podName,
    required this.namespace,
    required this.kubernetesClient,
  });

  @override
  State<PodDetailScreen> createState() => _PodDetailScreenState();
}

class _PodDetailScreenState extends State<PodDetailScreen> {
  dynamic _podDetails;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<dynamic>? _podDetailsSubscription;

  // Events state
  List<PodEvent> _events = [];
  StreamSubscription<List<PodEvent>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _startWatchingPodDetails();
    _startWatchingPodEvents();
  }

  @override
  void dispose() {
    _podDetailsSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _startWatchingPodDetails() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _podDetailsSubscription = PodService.watchPodDetails(
      widget.kubernetesClient,
      widget.namespace,
      widget.podName,
    ).listen(
      (details) {
        if (mounted) {
          setState(() {
            _podDetails = details;
            _isLoading = false;
            _error = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          // Check if it's a 404 error (resource not found)
          final errorString = error.toString();
          if (errorString.contains('404') || errorString.contains('not found')) {
            // Show error message and navigate back
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pod "${widget.podName}" no longer exists'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
            // Navigate back to the list screen
            Navigator.of(context).pop();
          } else {
            setState(() {
              _error = errorString;
              _isLoading = false;
            });
          }
        }
      },
    );
  }

  void _startWatchingPodEvents() {
    _eventsSubscription = PodService.watchPodEvents(
      widget.kubernetesClient,
      widget.namespace,
      widget.podName,
    ).listen(
      (events) {
        if (mounted) {
          setState(() {
            _events = events;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching pod events: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.podName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Pod',
            onPressed: () => _showDeleteConfirmationDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Shows a confirmation dialog before deleting the pod
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Delete Pod'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this pod?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Pod Details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.podName}', style: const TextStyle(fontSize: 12)),
                    Text('Namespace: ${widget.namespace}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _deletePod();
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Deletes the pod and navigates back
  Future<void> _deletePod() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Deleting pod...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Delete the pod
      await PodService.deletePod(
        widget.kubernetesClient,
        widget.namespace,
        widget.podName,
      );

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pod "${widget.podName}" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Go back to the list
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete pod: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Shows a drawer with container details
  void _showContainerDrawer(dynamic container) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Container Details',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: _ContainerDrawer(
              container: container,
              kubernetesClient: widget.kubernetesClient,
              namespace: widget.namespace,
              podName: widget.podName,
              podDetails: _podDetails,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading pod details'),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _podDetailsSubscription?.cancel();
                _startWatchingPodDetails();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_podDetails == null) {
      return const Center(
        child: Text('No pod details available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildContainersCard(),
          const SizedBox(height: 16),
          _buildLabelsCard(),
          const SizedBox(height: 16),
          if (_podDetails.metadata?.annotations != null && _podDetails.metadata!.annotations!.isNotEmpty) ...[
            _buildAnnotationsCard(),
            const SizedBox(height: 16),
          ],
          if (_podDetails.spec?.volumes != null && _podDetails.spec!.volumes!.isNotEmpty) ...[
            _buildVolumesCard(),
            const SizedBox(height: 16),
          ],
          _buildConditionsCard(),
          const SizedBox(height: 16),
          _buildEventsCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    // Check if pod is terminating (has deletionTimestamp)
    String status;
    if (_podDetails.metadata?.deletionTimestamp != null) {
      status = 'Terminating';
    } else {
      status = _podDetails.status?.phase ?? 'Unknown';
    }
    final statusColor = _getStatusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Basic Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.label_outline, 'Name', _podDetails.metadata?.name ?? 'N/A'),
            _buildInfoRow(Icons.folder_outlined, 'Namespace', _podDetails.metadata?.namespace ?? 'N/A'),
            _buildInfoRow(Icons.circle, 'Status', status, valueColor: statusColor),
            _buildInfoRow(Icons.dns_outlined, 'Node', _podDetails.spec?.nodeName ?? 'N/A'),
            _buildInfoRow(Icons.access_time, 'Created', _formatTimestamp(_podDetails.metadata?.creationTimestamp)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'succeeded':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'terminating':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return timestamp.toString();
    }
  }

  Widget _buildLabelsCard() {
    final labels = _podDetails.metadata?.labels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Labels',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (labels == null || labels.isEmpty)
              Text('No labels', style: TextStyle(color: Colors.grey[400], fontSize: 13))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels.entries.map<Widget>((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationsCard() {
    final annotations = _podDetails.metadata?.annotations;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Annotations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (annotations == null || annotations.isEmpty)
              Text('No annotations', style: TextStyle(color: Colors.grey[400], fontSize: 13))
            else
              ...annotations.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          entry.key,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: SelectableText(
                          entry.value.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumesCard() {
    final volumes = _podDetails.spec?.volumes ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Volumes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${volumes.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...volumes.map((volume) => _buildVolumeItem(volume)),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeItem(dynamic volume) {
    final name = volume.name ?? 'Unknown';
    String volumeType = 'Unknown';
    String details = '';

    // Determine volume type and details
    if (volume.configMap != null) {
      volumeType = 'ConfigMap';
      details = volume.configMap.name ?? '';
    } else if (volume.secret != null) {
      volumeType = 'Secret';
      details = volume.secret.secretName ?? '';
    } else if (volume.persistentVolumeClaim != null) {
      volumeType = 'PVC';
      details = volume.persistentVolumeClaim.claimName ?? '';
    } else if (volume.emptyDir != null) {
      volumeType = 'EmptyDir';
      details = volume.emptyDir.medium != null ? 'Medium: ${volume.emptyDir.medium}' : 'Default';
    } else if (volume.hostPath != null) {
      volumeType = 'HostPath';
      details = volume.hostPath.path ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  volumeType,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: SelectableText(
                details,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContainersCard() {
    final containers = _podDetails.spec?.containers ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_in_ar_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Containers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${containers.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (containers.isEmpty)
              Text('No containers', style: TextStyle(color: Colors.grey[400], fontSize: 13))
            else
              ...containers.map((container) => _buildContainerItem(container)),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerItem(dynamic container) {
    return InkWell(
      onTap: () => _showContainerDrawer(container),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.widgets_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            _buildContainerDetail(Icons.image_outlined, 'Image', container.image ?? 'N/A'),
            const SizedBox(height: 6),
            _buildContainerDetail(Icons.download_outlined, 'Pull Policy', container.imagePullPolicy ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsCard() {
    final conditions = _podDetails.status?.conditions ?? [];

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Icon(Icons.checklist_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  'Conditions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${conditions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            if (conditions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No conditions', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              )
            else
              ...conditions.map((condition) => _buildConditionItem(condition)),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionItem(dynamic condition) {
    final isTrue = condition.status == 'True';
    final conditionType = condition.type ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTrue
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTrue ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTrue ? Icons.check_circle : Icons.cancel,
            color: isTrue ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conditionType,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                if (condition.reason != null)
                  Text(
                    condition.reason,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isTrue ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              condition.status ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_events.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_events.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No events found',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _events.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return _buildEventItem(event);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(PodEvent event) {
    Color typeColor;
    IconData typeIcon;

    switch (event.type.toLowerCase()) {
      case 'warning':
        typeColor = Colors.orange;
        typeIcon = Icons.warning_amber;
        break;
      case 'error':
        typeColor = Colors.red;
        typeIcon = Icons.error_outline;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.info_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(typeIcon, size: 20, color: typeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      event.reason,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (event.count > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'x${event.count}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (event.timestamp != null)
                    Text(
                      event.timestamp!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                event.message,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Source: ${event.source}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Drawer widget that shows container details
class _ContainerDrawer extends StatefulWidget {
  final dynamic container;
  final Kubernetes kubernetesClient;
  final String namespace;
  final String podName;
  final dynamic podDetails;

  const _ContainerDrawer({
    required this.container,
    required this.kubernetesClient,
    required this.namespace,
    required this.podName,
    required this.podDetails,
  });

  @override
  State<_ContainerDrawer> createState() => _ContainerDrawerState();
}

class _ContainerDrawerState extends State<_ContainerDrawer> {
  StreamSubscription<List<dynamic>>? _envVarsSubscription;
  List<dynamic> _envVars = [];
  final Set<String> _visibleSecrets = {}; // Track which secret env vars are visible

  // Metrics tracking
  StreamSubscription<PodMetrics?>? _metricsSubscription;
  final List<ContainerMetrics> _metricsHistory = [];
  ContainerMetrics? _currentMetrics;
  bool _isMetricsExpanded = false; // Collapsed by default

  @override
  void initState() {
    super.initState();
    // Defer API call until after drawer animation completes (300ms)
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _startWatchingEnvVars();
        _startWatchingMetrics();
      }
    });
  }

  @override
  void dispose() {
    _envVarsSubscription?.cancel();
    _metricsSubscription?.cancel();
    super.dispose();
  }

  void _startWatchingMetrics() {
    _metricsSubscription = PodMetricsService.watchPodMetrics(
      widget.kubernetesClient,
      widget.namespace,
      widget.podName,
    ).listen((podMetrics) {
      if (podMetrics != null && mounted) {
        // Find metrics for this specific container
        final containerMetrics = podMetrics.containers.firstWhere(
          (c) => c.name == widget.container.name,
          orElse: () => ContainerMetrics(name: widget.container.name ?? '', cpuMillicores: 0, memoryBytes: 0),
        );

        setState(() {
          _currentMetrics = containerMetrics;
          _metricsHistory.add(containerMetrics);

          // Keep only last 7 data points (70 seconds of history at 10s intervals)
          if (_metricsHistory.length > 7) {
            _metricsHistory.removeAt(0);
          }
        });
      }
    });
  }

  void _startWatchingEnvVars() {
    _envVarsSubscription = PodService.watchContainerEnvVars(
      widget.kubernetesClient,
      widget.namespace,
      widget.podName,
      widget.container.name,
    ).listen(
      (envVars) {
        if (mounted) {
          setState(() {
            _envVars = envVars;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching env vars: $error');
      },
    );
  }

  void _openContainerLogs() {
    final containerName = widget.container.name ?? 'unknown';
    final id = 'logs-${widget.namespace}-${widget.podName}-$containerName-${DateTime.now().millisecondsSinceEpoch}';

    SessionManager().openLogs(
      id: id,
      title: 'Logs: ${widget.podName}/$containerName',
      kubernetesClient: widget.kubernetesClient,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: containerName,
      isPodLog: true,
    );
  }

  void _openContainerTerminal() {
    final containerName = widget.container.name ?? 'unknown';
    final id = 'terminal-${widget.namespace}-${widget.podName}-$containerName-${DateTime.now().millisecondsSinceEpoch}';

    SessionManager().openTerminal(
      id: id,
      title: 'Terminal: ${widget.podName}/$containerName',
      kubernetesClient: widget.kubernetesClient,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: containerName,
    );
  }

  /// Check if the container is currently running
  bool _isContainerRunning() {
    final containerStatuses = widget.podDetails?.status?.containerStatuses ?? [];
    final containerName = widget.container.name;

    for (var status in containerStatuses) {
      if (status.name == containerName) {
        // Check if the container state is running
        return status.state?.running != null;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ports = widget.container.ports ?? [];
    final isRunning = _isContainerRunning();

    return SizedBox(
      width: 800,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.widgets_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.container.name ?? 'Container',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.terminal),
                    onPressed: isRunning ? _openContainerTerminal : null,
                    tooltip: isRunning ? 'Open Terminal' : 'Container not running',
                  ),
                  IconButton(
                    icon: const Icon(Icons.article_outlined),
                    onPressed: _openContainerLogs,
                    tooltip: 'View Logs',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildPortsSection(ports),
                    ),
                    if (_currentMetrics != null) ...[
                      _buildMetricsSection(),
                      const SizedBox(height: 24),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildEnvironmentVariablesSection(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortsSection(List<dynamic> ports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_ethernet, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Ports',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${ports.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ports.isEmpty)
          Text(
            'No ports exposed',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          )
        else
          ...ports.map((port) => _buildPortItem(port)),
      ],
    );
  }

  Widget _buildPortItem(dynamic port) {
    final containerPort = port.containerPort?.toString() ?? 'N/A';
    final protocol = port.protocol ?? 'TCP';
    final name = port.name;

    return ListenableBuilder(
      listenable: PortForwardManager(),
      builder: (context, _) {
        final isForwarded = PortForwardManager().isPortForwarded(
          widget.namespace,
          widget.podName,
          containerPort,
        );
        final session = PortForwardManager().getSessionForPort(
          widget.namespace,
          widget.podName,
          containerPort,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isForwarded
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isForwarded ? Icons.forward : Icons.lan_outlined,
                size: 18,
                color: isForwarded
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != null)
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    Text(
                      isForwarded && session != null
                          ? 'Port $containerPort → localhost:${session.localPort}'
                          : 'Port $containerPort',
                      style: TextStyle(
                        color: name != null ? Colors.grey[400] : null,
                        fontSize: name != null ? 13 : 14,
                        fontWeight: name != null ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  protocol,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(isForwarded ? Icons.stop_circle_outlined : Icons.forward),
                iconSize: 20,
                color: isForwarded ? Theme.of(context).colorScheme.error : null,
                tooltip: isForwarded ? 'Stop Port Forward' : 'Port Forward',
                onPressed: () {
                  if (isForwarded && session != null) {
                    PortForwardManager().stopPortForward(session.id);
                  } else {
                    _showPortForwardDialog(containerPort);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPortForwardDialog(String containerPort) {
    final localPortController = TextEditingController(text: containerPort);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Port Forward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forward port $containerPort to local port:'),
            const SizedBox(height: 16),
            TextField(
              controller: localPortController,
              decoration: const InputDecoration(
                labelText: 'Local Port',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final localPort = localPortController.text;
              Navigator.of(context).pop();
              _startPortForward(containerPort, localPort);
            },
            icon: const Icon(Icons.forward),
            label: const Text('Forward'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPortForward(String containerPort, String localPort) async {
    // Check if local port is already in use
    if (PortForwardManager().isLocalPortInUse(localPort)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Local port $localPort is already in use by another port forward'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    try {
      await PortForwardManager().startPortForward(
        namespace: widget.namespace,
        podName: widget.podName,
        containerPort: containerPort,
        localPort: localPort,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Port forward started: localhost:$localPort → ${widget.podName}:$containerPort'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start port forward: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildEnvironmentVariablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Environment Variables',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_envVars.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_envVars.isEmpty)
          Text(
            'No environment variables',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          )
        else
          ..._envVars.map((envVar) => _buildEnvVarItem(envVar)),
      ],
    );
  }

  Widget _buildEnvVarItem(dynamic envVar) {
    // Handle both V1EnvVar objects and Map objects
    String name;
    String displayValue;
    String? source;
    bool isSecret = false;

    if (envVar is Map) {
      // Resolved env var from ConfigMap or Secret
      name = envVar['name'] ?? 'Unknown';
      displayValue = envVar['value'] ?? 'N/A';
      source = envVar['source'];
      isSecret = envVar['isSecret'] ?? false;

      // Decode base64 for secrets if needed
      if (isSecret && displayValue != 'N/A') {
        try {
          displayValue = utf8.decode(base64.decode(displayValue));
        } catch (e) {
          // If decoding fails, keep original value
        }
      }
    } else {
      // Direct V1EnvVar object
      name = envVar.name ?? 'Unknown';
      final value = envVar.value;
      final valueFrom = envVar.valueFrom;

      if (value != null) {
        displayValue = value;
      } else if (valueFrom != null) {
        if (valueFrom.secretKeyRef != null) {
          displayValue = 'Reference: ${valueFrom.secretKeyRef.key}';
          source = 'Secret: ${valueFrom.secretKeyRef.name}';
          isSecret = true;
        } else if (valueFrom.configMapKeyRef != null) {
          displayValue = 'Reference: ${valueFrom.configMapKeyRef.key}';
          source = 'ConfigMap: ${valueFrom.configMapKeyRef.name}';
        } else if (valueFrom.fieldRef != null) {
          displayValue = valueFrom.fieldRef.fieldPath ?? 'N/A';
          source = 'Field Reference';
        } else if (valueFrom.resourceFieldRef != null) {
          displayValue = valueFrom.resourceFieldRef.resource ?? 'N/A';
          source = 'Resource Reference';
        } else {
          displayValue = 'N/A';
        }
      } else {
        displayValue = 'N/A';
      }
    }

    final isVisible = _visibleSecrets.contains(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSecret
                    ? (isVisible ? Icons.lock_open_outlined : Icons.lock_outline)
                    : Icons.code,
                size: 18,
                color: isSecret
                    ? (isVisible ? Colors.green : Colors.amber)
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (source != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSecret
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      source,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSecret ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (isSecret) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isVisible) {
                        _visibleSecrets.remove(name);
                      } else {
                        _visibleSecrets.add(name);
                      }
                    });
                  },
                  tooltip: isVisible ? 'Hide value' : 'Show value',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          if (isVisible || !isSecret) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: SelectableText(
                      displayValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: displayValue));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied "$name" to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy to clipboard',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Text(
                '••••••••',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    // Get resource requests and limits
    final resources = widget.container.resources;
    final cpuRequest = resources?.requests?['cpu'] as String?;
    final cpuLimit = resources?.limits?['cpu'] as String?;
    final memoryRequest = resources?.requests?['memory'] as String?;
    final memoryLimit = resources?.limits?['memory'] as String?;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: _isMetricsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isMetricsExpanded = expanded;
          });
        },
        leading: Icon(Icons.show_chart, size: 20, color: Theme.of(context).colorScheme.primary),
        title: Text(
          'Resource Usage',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: _currentMetrics != null
            ? Text(
                'CPU: ${_currentMetrics!.cpuCores.toStringAsFixed(3)} cores  •  Memory: ${_currentMetrics!.memoryMB.toStringAsFixed(1)} MB',
                style: const TextStyle(fontSize: 12),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CPU Chart
                _buildChartWithLimits(
                  title: 'CPU Usage',
                  icon: Icons.memory,
                  color: Colors.blue,
                  currentValue: _currentMetrics!.cpuCores,
                  requestValue: cpuRequest != null ? _parseCpuToDouble(cpuRequest) : null,
                  limitValue: cpuLimit != null ? _parseCpuToDouble(cpuLimit) : null,
                  unit: 'cores',
                  isCpu: true,
                ),
                const SizedBox(height: 24),
                // Memory Chart
                _buildChartWithLimits(
                  title: 'Memory Usage',
                  icon: Icons.storage,
                  color: Colors.green,
                  currentValue: _currentMetrics!.memoryMB,
                  requestValue: memoryRequest != null ? _parseMemoryToMB(memoryRequest) : null,
                  limitValue: memoryLimit != null ? _parseMemoryToMB(memoryLimit) : null,
                  unit: 'MB',
                  isCpu: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseCpuToDouble(String cpuStr) {
    if (cpuStr.endsWith('m')) {
      // Millicores (e.g., "250m")
      final millicores = int.tryParse(cpuStr.substring(0, cpuStr.length - 1)) ?? 0;
      return millicores / 1000.0;
    } else {
      // Cores (e.g., "1" or "0.5")
      return double.tryParse(cpuStr) ?? 0;
    }
  }

  double _parseMemoryToMB(String memoryStr) {
    if (memoryStr.endsWith('Ki')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value / 1024.0;
    } else if (memoryStr.endsWith('Mi')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value.toDouble();
    } else if (memoryStr.endsWith('Gi')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value * 1024.0;
    } else {
      // Assume bytes
      final bytes = int.tryParse(memoryStr) ?? 0;
      return bytes / (1024 * 1024);
    }
  }

  Widget _buildChartWithLimits({
    required String title,
    required IconData icon,
    required Color color,
    required double currentValue,
    required double? requestValue,
    required double? limitValue,
    required String unit,
    required bool isCpu,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Current value with request and limit
        Row(
          children: [
            _buildMetricBadge('Actual', '${currentValue.toStringAsFixed(isCpu ? 3 : 1)} $unit', Colors.blue),
            const SizedBox(width: 8),
            _buildMetricBadge('Request', requestValue != null ? '${requestValue.toStringAsFixed(isCpu ? 3 : 1)} $unit' : 'Not set', Colors.orange),
            const SizedBox(width: 8),
            _buildMetricBadge('Limit', limitValue != null ? '${limitValue.toStringAsFixed(isCpu ? 3 : 1)} $unit' : 'Not set', Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        // Chart
        SizedBox(
          height: 200,
          child: _buildChart(
            isCpu: isCpu,
            requestValue: requestValue,
            limitValue: limitValue,
            color: color,
            unit: unit,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChart({
    required bool isCpu,
    required double? requestValue,
    required double? limitValue,
    required Color color,
    required String unit,
  }) {
    if (_metricsHistory.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _metricsHistory.length; i++) {
      final value = isCpu ? _metricsHistory[i].cpuCores : _metricsHistory[i].memoryMB;
      spots.add(FlSpot(i.toDouble(), value));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    // Adjust max to include limit if it exists
    var effectiveMax = maxY;
    if (limitValue != null && limitValue > effectiveMax) {
      effectiveMax = limitValue;
    }
    if (requestValue != null && requestValue > effectiveMax) {
      effectiveMax = requestValue;
    }

    // Calculate interval, ensuring it's never zero
    final range = effectiveMax - (minY > 0 ? 0 : minY);
    final horizontalInterval = range > 0 ? range / 4 : 1.0;

    // Build horizontal lines for request and limit
    final extraLines = <HorizontalLine>[];
    if (requestValue != null) {
      extraLines.add(HorizontalLine(
        y: requestValue,
        color: Colors.orange.withValues(alpha: 0.5),
        strokeWidth: 2,
        dashArray: [5, 5],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 5, bottom: 5),
          style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
          labelResolver: (line) => 'Request',
        ),
      ));
    }
    if (limitValue != null) {
      extraLines.add(HorizontalLine(
        y: limitValue,
        color: Colors.red.withValues(alpha: 0.5),
        strokeWidth: 2,
        dashArray: [5, 5],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 5, top: 5),
          style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
          labelResolver: (line) => 'Limit',
        ),
      ));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: horizontalInterval,
          drawVerticalLine: false,
        ),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                // Only show 4 labels
                final effectiveMin = minY > 0 ? 0 : minY;
                final step = (effectiveMax * 1.1 - effectiveMin) / 3;

                for (int i = 0; i <= 3; i++) {
                  final targetValue = effectiveMin + (step * i);
                  if ((value - targetValue).abs() < step * 0.01) {
                    return Text(
                      value.toStringAsFixed(isCpu ? 2 : 0),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
        minY: minY > 0 ? 0 : minY,
        maxY: effectiveMax * 1.1,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final textStyle = TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                final children = <TextSpan>[TextSpan(text: '\nActual: ${touchedSpot.y.toStringAsFixed(isCpu ? 3 : 1)} $unit')];
                if (requestValue != null) {
                  children.add(TextSpan(text: '\nRequest: ${requestValue.toStringAsFixed(isCpu ? 3 : 1)} $unit'));
                }
                if (limitValue != null) {
                  children.add(TextSpan(text: '\nLimit: ${limitValue.toStringAsFixed(isCpu ? 3 : 1)} $unit'));
                }
                return LineTooltipItem(
                  '${((spots.length - touchedSpot.x - 1) * 10).toStringAsFixed(0)}s',
                  textStyle,
                  children: children,
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

