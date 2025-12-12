import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/secret_info.dart';
import '../screens/secret_detail_screen.dart';

/// Widget that displays a list of Kubernetes secrets
class SecretsList extends StatelessWidget {
  const SecretsList({
    super.key,
    required this.secrets,
    required this.isLoading,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<SecretInfo> secrets;
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
            Text('Loading secrets...'),
          ],
        ),
      );
    }

    if (secrets.isEmpty) {
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
              'No secrets found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: secrets.length,
      itemBuilder: (context, index) {
        final secret = secrets[index];
        return _buildSecretCard(context, secret);
      },
    );
  }

  /// Builds a card widget for a single secret
  Widget _buildSecretCard(BuildContext context, SecretInfo secret) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SecretDetailScreen(
                secretName: secret.name,
                namespace: secret.namespace,
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
            // Secret name and age
            Row(
              children: [
                // Lock icon
                Icon(
                  Icons.lock,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                // Secret name
                Expanded(
                  child: Text(
                    secret.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Age badge
                if (secret.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      secret.age!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Secret details
            _buildDetailRow(context, 'Namespace', secret.namespace),
            _buildDetailRow(context, 'Type', secret.type),
            _buildDetailRow(context, 'Data Keys', '${secret.dataCount}'),
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
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

