import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/custom_resource_info.dart';
import '../screens/custom_resource_detail_screen.dart';

/// Widget that displays a list of Kubernetes custom resources
class CustomResourcesList extends StatelessWidget {
  const CustomResourcesList({
    super.key,
    required this.resources,
    required this.isLoading,
    this.crd,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<CustomResourceInfo> resources;
  final bool isLoading;
  final CustomResourceDefinitionInfo? crd;
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
            Text('Loading custom resources...'),
          ],
        ),
      );
    }

    if (crd == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a custom resource type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${crd?.kind ?? 'custom'} resources found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        return _buildResourceCard(context, resource);
      },
    );
  }

  /// Builds a card widget for a single custom resource
  Widget _buildResourceCard(BuildContext context, CustomResourceInfo resource) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomResourceDetailScreen(
                resourceName: resource.name,
                namespace: resource.namespace,
                crd: crd!,
                kubernetesClient: kubernetesClient,
              ),
            ),
          );

          // Resume watching when returning
          onResumeWatching();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resource name and age
              Row(
                children: [
                  // Extension icon
                  Icon(
                    Icons.extension,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  // Resource name
                  Expanded(
                    child: Text(
                      resource.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Age badge
                  if (resource.age != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        resource.age!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Resource details
              _buildDetailRow(context, 'Namespace', resource.namespace),
              _buildDetailRow(context, 'Kind', resource.kind),
              _buildDetailRow(context, 'API Version', resource.apiVersion),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single detail row
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

