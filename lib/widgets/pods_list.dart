import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/pod_info.dart';
import '../screens/pod_detail_screen.dart';

/// Widget that displays a list of Kubernetes pods
class PodsList extends StatelessWidget {
  const PodsList({
    super.key,
    required this.pods,
    required this.isLoading,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<PodInfo> pods;
  final bool isLoading;
  final Kubernetes kubernetesClient;
  final VoidCallback onPauseWatching;
  final VoidCallback onResumeWatching;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading pods...'),
          ],
        ),
      );
    }

    if (pods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.widgets,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No pods found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: pods.length,
      itemBuilder: (context, index) {
        final pod = pods[index];
        return _buildPodCard(context, pod);
      },
    );
  }

  /// Builds a card widget for a single pod
  Widget _buildPodCard(BuildContext context, PodInfo pod) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PodDetailScreen(
                podName: pod.name,
                namespace: pod.namespace,
                kubernetesClient: kubernetesClient,
              ),
            ),
          );

          // Resume watching when returning from detail screen
          onResumeWatching();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pod name and status
            Row(
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(context, pod.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Pod name
                Expanded(
                  child: Text(
                    pod.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Age
                if (pod.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pod.age!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Pod details
            Row(
              children: [
                // Namespace
                _buildDetailChip(
                  context,
                  icon: Icons.folder,
                  label: pod.namespace,
                ),
                const SizedBox(width: 8),
                // Status
                _buildDetailChip(
                  context,
                  icon: Icons.info_outline,
                  label: pod.status,
                ),
                const SizedBox(width: 8),
                // Restart count
                _buildDetailChip(
                  context,
                  icon: Icons.refresh,
                  label: '${pod.restartCount} restarts',
                ),
              ],
            ),
            
            // Container names
            if (pod.containerNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: pod.containerNames.map((containerName) {
                  return Chip(
                    label: Text(
                      containerName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  /// Builds a small detail chip with icon and label
  Widget _buildDetailChip(BuildContext context, {required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  /// Returns the appropriate color for the pod status
  Color _getStatusColor(BuildContext context, String status) {
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
      case 'unknown':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

