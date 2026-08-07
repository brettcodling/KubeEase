import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/service_info.dart';
import '../screens/service_detail_screen.dart';

/// Widget that displays a list of Kubernetes services
class ServicesList extends StatelessWidget {
  const ServicesList({
    super.key,
    required this.services,
    required this.isLoading,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<ServiceInfo> services;
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
            Text('Loading services...'),
          ],
        ),
      );
    }

    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No services found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(context, service);
      },
    );
  }

  /// Builds a card widget for a single service
  Widget _buildServiceCard(BuildContext context, ServiceInfo service) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailScreen(
                serviceName: service.name,
                namespace: service.namespace,
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
            // Service name and age
            Row(
              children: [
                // Network check icon
                Icon(
                  Icons.network_check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                // Service name
                Expanded(
                  child: Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Age badge
                if (service.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.age!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Service details
            _buildDetailRow(context, 'Namespace', service.namespace),
            _buildDetailRow(context, 'Type', service.type),
          ],
        ),
      ),
      ),
    );
  }

  /// Builds a detail row with label and value
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              overflow: TextOverflow.ellipsis,
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

