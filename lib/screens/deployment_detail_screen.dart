import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../services/deployments/deployment_service.dart';

/// Screen that displays detailed information about a Kubernetes Deployment
class DeploymentDetailScreen extends StatefulWidget {
  final String deploymentName;
  final String namespace;
  final Kubernetes kubernetesClient;

  const DeploymentDetailScreen({
    super.key,
    required this.deploymentName,
    required this.namespace,
    required this.kubernetesClient,
  });

  @override
  State<DeploymentDetailScreen> createState() => _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState extends State<DeploymentDetailScreen> {
  dynamic _deploymentDetails;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<dynamic>? _deploymentDetailsSubscription;

  @override
  void initState() {
    super.initState();
    _startWatchingDeploymentDetails();
  }

  @override
  void dispose() {
    _deploymentDetailsSubscription?.cancel();
    super.dispose();
  }

  void _startWatchingDeploymentDetails() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _deploymentDetailsSubscription = DeploymentService.watchDeploymentDetails(
      widget.kubernetesClient,
      widget.namespace,
      widget.deploymentName,
    ).listen(
      (details) {
        if (mounted) {
          setState(() {
            _deploymentDetails = details;
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
                content: Text('Deployment "${widget.deploymentName}" no longer exists'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deploymentName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
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
            const Text('Error loading deployment details'),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _deploymentDetailsSubscription?.cancel();
                _startWatchingDeploymentDetails();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_deploymentDetails == null) {
      return const Center(
        child: Text('No deployment details available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildScalingCard(),
          const SizedBox(height: 16),
          _buildLabelsCard(),
          const SizedBox(height: 16),
          if (_deploymentDetails.metadata?.annotations != null && _deploymentDetails.metadata!.annotations!.isNotEmpty) ...[
            _buildAnnotationsCard(),
            const SizedBox(height: 16),
          ],
          if (_deploymentDetails.spec?.selector?.matchLabels != null) ...[
            _buildSelectorCard(),
            const SizedBox(height: 16),
          ],
          if (_deploymentDetails.spec?.strategy != null) ...[
            _buildStrategyCard(),
            const SizedBox(height: 16),
          ],
          _buildConditionsCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final replicas = _deploymentDetails.spec?.replicas ?? 0;
    final readyReplicas = _deploymentDetails.status?.readyReplicas ?? 0;
    final availableReplicas = _deploymentDetails.status?.availableReplicas ?? 0;
    final updatedReplicas = _deploymentDetails.status?.updatedReplicas ?? 0;

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
            _buildInfoRow(Icons.label_outline, 'Name', _deploymentDetails.metadata?.name ?? 'N/A'),
            _buildInfoRow(Icons.folder_outlined, 'Namespace', _deploymentDetails.metadata?.namespace ?? 'N/A'),
            _buildInfoRow(Icons.apps, 'Replicas', '$replicas'),
            _buildInfoRow(Icons.check_circle_outline, 'Ready', '$readyReplicas'),
            _buildInfoRow(Icons.cloud_done_outlined, 'Available', '$availableReplicas'),
            _buildInfoRow(Icons.update, 'Updated', '$updatedReplicas'),
            _buildInfoRow(Icons.access_time, 'Created', _formatTimestamp(_deploymentDetails.metadata?.creationTimestamp)),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }

      return '${dateTime.toLocal()}'.split('.')[0];
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildScalingCard() {
    final currentReplicas = _deploymentDetails.spec?.replicas ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Scale Deployment',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Current Replicas: $currentReplicas',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showScaleDialog,
                icon: const Icon(Icons.tune),
                label: const Text('Scale Replicas'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScaleDialog() async {
    final currentReplicas = _deploymentDetails.spec?.replicas ?? 0;
    double sliderValue = currentReplicas.toDouble();

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Scale Deployment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deployment: ${widget.deploymentName}'),
              const SizedBox(height: 8),
              Text('Namespace: ${widget.namespace}'),
              const SizedBox(height: 24),
              Text(
                'Replicas: ${sliderValue.toInt()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: sliderValue,
                min: 0,
                max: 100,
                divisions: 100,
                label: sliderValue.toInt().toString(),
                onChanged: (value) {
                  setState(() {
                    sliderValue = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0', style: TextStyle(color: Colors.grey[600])),
                  Text('100', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(sliderValue.toInt()),
              child: const Text('Scale'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    // Show confirmation if scaling to 0
    if (result == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Scale to Zero'),
          content: Text(
            'Are you sure you want to scale "${widget.deploymentName}" to 0 replicas? This will stop all pods.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Scale to 0'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Perform the scaling
    try {
      await DeploymentService.scaleDeployment(
        widget.kubernetesClient,
        widget.namespace,
        widget.deploymentName,
        result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deployment "${widget.deploymentName}" scaled to $result replicas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scale deployment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildLabelsCard() {
    final labels = _deploymentDetails.metadata?.labels ?? {};

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

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
            if (labels.isEmpty)
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
    final annotations = _deploymentDetails.metadata?.annotations;

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

  Widget _buildSelectorCard() {
    final matchLabels = _deploymentDetails.spec?.selector?.matchLabels ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Selector',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (matchLabels.isEmpty)
              Text('No selector labels', style: TextStyle(color: Colors.grey[400], fontSize: 13))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: matchLabels.entries.map<Widget>((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard() {
    final strategy = _deploymentDetails.spec?.strategy;
    final strategyType = strategy?.type ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Deployment Strategy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.sync, 'Type', strategyType),
            if (strategyType == 'RollingUpdate' && strategy?.rollingUpdate != null) ...[
              _buildInfoRow(
                Icons.arrow_upward,
                'Max Surge',
                strategy!.rollingUpdate!.maxSurge?.toString() ?? 'N/A',
              ),
              _buildInfoRow(
                Icons.arrow_downward,
                'Max Unavailable',
                strategy.rollingUpdate!.maxUnavailable?.toString() ?? 'N/A',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsCard() {
    final conditions = _deploymentDetails.status?.conditions ?? [];

    if (conditions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Conditions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...conditions.map((condition) {
              final type = condition.type ?? 'Unknown';
              final status = condition.status ?? 'Unknown';
              final reason = condition.reason ?? '';
              final message = condition.message ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'True' ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: status == 'True' ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(
                            color: status == 'True' ? Colors.green : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: $reason',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
