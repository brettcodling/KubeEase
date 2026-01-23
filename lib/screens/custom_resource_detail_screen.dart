import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/custom_resource_info.dart';
import '../services/custom_resources/custom_resource_service.dart';

/// Screen that displays detailed information about a Kubernetes Custom Resource
class CustomResourceDetailScreen extends StatefulWidget {
  final String resourceName;
  final String namespace;
  final CustomResourceDefinitionInfo crd;
  final Kubernetes kubernetesClient;

  const CustomResourceDetailScreen({
    super.key,
    required this.resourceName,
    required this.namespace,
    required this.crd,
    required this.kubernetesClient,
  });

  @override
  State<CustomResourceDetailScreen> createState() => _CustomResourceDetailScreenState();
}

class _CustomResourceDetailScreenState extends State<CustomResourceDetailScreen> {
  dynamic _resourceDetails;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadResourceDetails();
    // Refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadResourceDetails();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadResourceDetails() async {
    try {
      // Use kubectl to get the resource details
      // Use full resource type (plural.group) to avoid ambiguity
      final resourceType = widget.crd.group.isEmpty
          ? widget.crd.plural
          : '${widget.crd.plural}.${widget.crd.group}';

      final args = widget.crd.scope == 'Cluster'
          ? ['get', resourceType, widget.resourceName, '-o', 'json']
          : ['get', resourceType, widget.resourceName, '-n', widget.namespace, '-o', 'json'];

      final result = await Process.run('kubectl', args);

      if (result.exitCode != 0) {
        // Check if resource was deleted
        if (result.stderr.toString().contains('not found') || result.stderr.toString().contains('NotFound')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.crd.kind} "${widget.resourceName}" no longer exists'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        }
        throw Exception('Failed to fetch resource: ${result.stderr}');
      }

      final data = jsonDecode(result.stdout as String);
      
      if (mounted) {
        setState(() {
          _resourceDetails = data;
          _isLoading = false;
          _error = null;
        });
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resourceName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadResourceDetails,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete ${widget.crd.kind}',
            onPressed: () => _showDeleteConfirmationDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _resourceDetails == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading resource details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading resource',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildResourceDetails();
  }

  Widget _buildResourceDetails() {
    final metadata = _resourceDetails['metadata'] as Map<String, dynamic>?;
    final spec = _resourceDetails['spec'] as Map<String, dynamic>?;
    final status = _resourceDetails['status'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Card
          _buildInfoCard(metadata),
          const SizedBox(height: 16),

          // Labels Card
          if (metadata != null) ...[
            _buildLabelsCard(metadata),
            const SizedBox(height: 16),
          ],

          // Annotations Card
          if (metadata != null && metadata['annotations'] != null && (metadata['annotations'] as Map).isNotEmpty) ...[
            _buildAnnotationsCard(metadata),
            const SizedBox(height: 16),
          ],

          // Spec Card
          if (spec != null && spec.isNotEmpty) ...[
            _buildSpecCard(spec),
            const SizedBox(height: 16),
          ],

          // Status Card
          if (status != null && status.isNotEmpty)
            _buildStatusCard(status),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic>? metadata) {
    final creationTimestamp = metadata?['creationTimestamp'] as String?;
    final age = _formatTimestamp(creationTimestamp);
    final uid = metadata?['uid'] as String? ?? 'N/A';

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
                Text(
                  'Basic Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.label_outline, 'Name', widget.resourceName),
            if (widget.crd.scope == 'Namespaced')
              _buildInfoRow(Icons.folder_outlined, 'Namespace', widget.namespace),
            _buildInfoRow(Icons.category_outlined, 'Kind', widget.crd.kind),
            _buildInfoRow(Icons.api_outlined, 'API Version', widget.crd.apiVersion),
            _buildInfoRow(Icons.public_outlined, 'Scope', widget.crd.scope),
            _buildInfoRow(Icons.access_time, 'Created', age),
            _buildInfoRow(Icons.fingerprint, 'UID', uid),
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

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildLabelsCard(Map<String, dynamic> metadata) {
    final labels = metadata['labels'] as Map<String, dynamic>?;

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
                children: labels.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationsCard(Map<String, dynamic> metadata) {
    final annotations = metadata['annotations'] as Map<String, dynamic>?;

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

  Widget _buildSpecCard(Map<String, dynamic> spec) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Spec',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildKeyValueList(spec),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> status) {
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
                  'Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildKeyValueList(status),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueList(Map<String, dynamic> data, {int indent = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map) {
          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildKeyValueList(Map<String, dynamic>.from(value), indent: indent),
                ),
              ],
            ),
          );
        } else if (value is List) {
          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...value.asMap().entries.map((listEntry) {
                  if (listEntry.value is Map) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _buildKeyValueList(Map<String, dynamic>.from(listEntry.value), indent: 0),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 2),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 6, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              listEntry.value.toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }),
              ],
            ),
          );
        } else {
          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Text(
                    key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    value.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }
      }).toList(),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Delete Resource'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this ${widget.crd.kind}?',
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
                          'Resource Details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Kind: ${widget.crd.kind}', style: const TextStyle(fontSize: 12)),
                    Text('Name: ${widget.resourceName}', style: const TextStyle(fontSize: 12)),
                    if (widget.crd.scope == 'Namespaced')
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
                await _deleteResource();
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

  Future<void> _deleteResource() async {
    try {
      // Show loading indicator
      if (mounted) {
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
                Text('Deleting ${widget.crd.kind}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Delete the resource
      await CustomResourceService.deleteCustomResource(
        widget.kubernetesClient,
        widget.crd,
        widget.namespace,
        widget.resourceName,
      );

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.crd.kind} "${widget.resourceName}" deleted successfully'),
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
            content: Text('Failed to delete ${widget.crd.kind}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

