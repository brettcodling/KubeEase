import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:k8s/k8s.dart';
import '../services/secrets/secret_service.dart';

/// Screen that displays detailed information about a Kubernetes Secret
class SecretDetailScreen extends StatefulWidget {
  final String secretName;
  final String namespace;
  final Kubernetes kubernetesClient;

  const SecretDetailScreen({
    super.key,
    required this.secretName,
    required this.namespace,
    required this.kubernetesClient,
  });

  @override
  State<SecretDetailScreen> createState() => _SecretDetailScreenState();
}

class _SecretDetailScreenState extends State<SecretDetailScreen> {
  dynamic _secretDetails;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<dynamic>? _secretDetailsSubscription;
  final Set<String> _visibleSecrets = {}; // Track which secrets are visible

  @override
  void initState() {
    super.initState();
    _startWatchingSecretDetails();
  }

  @override
  void dispose() {
    _secretDetailsSubscription?.cancel();
    super.dispose();
  }

  void _startWatchingSecretDetails() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _secretDetailsSubscription = SecretService.watchSecretDetails(
      widget.kubernetesClient,
      widget.namespace,
      widget.secretName,
    ).listen(
      (details) {
        if (mounted) {
          setState(() {
            _secretDetails = details;
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
                content: Text('Secret "${widget.secretName}" no longer exists'),
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
        title: Text(widget.secretName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Secret',
            onPressed: () => _showDeleteConfirmationDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Shows a confirmation dialog before deleting the secret
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Delete Secret'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this secret?',
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
                          'Secret Details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.secretName}', style: const TextStyle(fontSize: 12)),
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
                await _deleteSecret();
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

  /// Deletes the secret and navigates back
  Future<void> _deleteSecret() async {
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
                Text('Deleting secret...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Delete the secret
      await SecretService.deleteSecret(
        widget.kubernetesClient,
        widget.namespace,
        widget.secretName,
      );

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Secret "${widget.secretName}" deleted successfully'),
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
            content: Text('Failed to delete secret: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
            const Text('Error loading secret details'),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _secretDetailsSubscription?.cancel();
                _startWatchingSecretDetails();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_secretDetails == null) {
      return const Center(
        child: Text('No secret details available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildDataKeysCard(),
          const SizedBox(height: 16),
          _buildLabelsCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
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
            _buildInfoRow(Icons.label_outline, 'Name', _secretDetails.metadata?.name ?? 'N/A'),
            _buildInfoRow(Icons.folder_outlined, 'Namespace', _secretDetails.metadata?.namespace ?? 'N/A'),
            _buildInfoRow(Icons.category_outlined, 'Type', _secretDetails.type ?? 'N/A'),
            _buildInfoRow(Icons.access_time, 'Created', _formatTimestamp(_secretDetails.metadata?.creationTimestamp)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDataKeysCard() {
    final data = _secretDetails.data;
    final dataCount = data?.keys.length ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Data Keys',
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
                    '$dataCount',
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
            if (data == null || data.isEmpty)
              Text('No data keys', style: TextStyle(color: Colors.grey[400], fontSize: 13))
            else
              ...data.keys.map((key) => _buildDataKeyItem(key)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataKeyItem(String key) {
    final isVisible = _visibleSecrets.contains(key);
    final data = _secretDetails.data;
    final encodedValue = data?[key];

    // Decode the base64 value
    String decodedValue = '';
    if (encodedValue != null) {
      try {
        decodedValue = utf8.decode(base64.decode(encodedValue));
      } catch (e) {
        decodedValue = 'Error decoding value';
      }
    }

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
                isVisible ? Icons.lock_open_outlined : Icons.lock_outline,
                size: 16,
                color: isVisible ? Colors.green : Colors.amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  key,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
              if (!isVisible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'hidden',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    if (isVisible) {
                      _visibleSecrets.remove(key);
                    } else {
                      _visibleSecrets.add(key);
                    }
                  });
                },
                tooltip: isVisible ? 'Hide value' : 'Show value',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (isVisible) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
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
                      decodedValue,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: decodedValue));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied "$key" to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy to clipboard',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabelsCard() {
    final labels = _secretDetails.metadata?.labels;

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
}

