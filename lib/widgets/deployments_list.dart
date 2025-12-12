import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/deployment_info.dart';
import '../screens/deployment_detail_screen.dart';

/// Widget that displays a list of Kubernetes deployments
class DeploymentsList extends StatelessWidget {
  const DeploymentsList({
    super.key,
    required this.deployments,
    required this.isLoading,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<DeploymentInfo> deployments;
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
            Text('Loading deployments...'),
          ],
        ),
      );
    }

    if (deployments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apps,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No deployments found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: deployments.length,
      itemBuilder: (context, index) {
        final deployment = deployments[index];
        return _buildDeploymentCard(context, deployment);
      },
    );
  }

  /// Builds a card widget for a single deployment
  Widget _buildDeploymentCard(BuildContext context, DeploymentInfo deployment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeploymentDetailScreen(
                deploymentName: deployment.name,
                namespace: deployment.namespace,
                kubernetesClient: kubernetesClient,
              ),
            ),
          );

          // Resume watching when returning
          onResumeWatching();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deployment name and age
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deployment.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Age
                  if (deployment.age != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        deployment.age!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Deployment details
              Row(
                children: [
                  // Namespace
                  _buildDetailChip(
                    context,
                    icon: Icons.folder,
                    label: deployment.namespace,
                  ),
                  const SizedBox(width: 8),
                  // Replicas status
                  _buildDetailChip(
                    context,
                    icon: Icons.apps,
                    label: '${deployment.readyReplicas}/${deployment.replicas} ready',
                    color: deployment.readyReplicas == deployment.replicas
                        ? Colors.green
                        : (deployment.readyReplicas == 0 ? Colors.red : Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(BuildContext context, {required IconData icon, required String label, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.2) ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

