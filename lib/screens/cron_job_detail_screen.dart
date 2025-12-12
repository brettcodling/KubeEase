import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../services/cron_jobs/cron_job_service.dart';
import '../services/logs_manager.dart';

/// Screen that displays detailed information about a Kubernetes CronJob
class CronJobDetailScreen extends StatefulWidget {
  final String cronJobName;
  final String namespace;
  final Kubernetes kubernetesClient;

  const CronJobDetailScreen({
    super.key,
    required this.cronJobName,
    required this.namespace,
    required this.kubernetesClient,
  });

  @override
  State<CronJobDetailScreen> createState() => _CronJobDetailScreenState();
}

class _CronJobDetailScreenState extends State<CronJobDetailScreen> {
  dynamic _cronJobDetails;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<dynamic>? _cronJobDetailsSubscription;
  List<dynamic> _jobs = [];
  Timer? _jobsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startWatchingCronJobDetails();
    _startWatchingJobs();
  }

  @override
  void dispose() {
    _cronJobDetailsSubscription?.cancel();
    _jobsRefreshTimer?.cancel();
    super.dispose();
  }

  void _startWatchingCronJobDetails() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _cronJobDetailsSubscription = CronJobService.watchCronJobDetails(
      widget.kubernetesClient,
      widget.namespace,
      widget.cronJobName,
    ).listen(
      (details) {
        if (mounted) {
          setState(() {
            _cronJobDetails = details;
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
                content: Text('CronJob "${widget.cronJobName}" no longer exists'),
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

  void _startWatchingJobs() {
    // Fetch jobs immediately
    _fetchJobs();

    // Set up periodic refresh every 5 seconds
    _jobsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchJobs();
    });
  }

  Future<void> _fetchJobs() async {
    try {
      final jobs = await CronJobService.fetchJobsForCronJob(
        widget.kubernetesClient,
        widget.namespace,
        widget.cronJobName,
      );

      if (mounted) {
        setState(() {
          _jobs = jobs;
        });
      }
    } catch (e) {
      // Silently fail - jobs are supplementary information
      debugPrint('Error fetching jobs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current suspend state
    final isSuspended = _cronJobDetails?.spec?.suspend ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cronJobName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Trigger CronJob Now',
            onPressed: () => _triggerCronJob(),
          ),
          IconButton(
            icon: Icon(isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline),
            tooltip: isSuspended ? 'Resume CronJob' : 'Suspend CronJob',
            onPressed: _cronJobDetails != null ? () => _toggleSuspend(isSuspended) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete CronJob',
            onPressed: () => _showDeleteConfirmationDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Triggers the cron job manually
  Future<void> _triggerCronJob() async {
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
                Text('Triggering cron job...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Trigger the cron job
      final jobName = await CronJobService.triggerCronJob(
        widget.kubernetesClient,
        widget.namespace,
        widget.cronJobName,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CronJob triggered successfully. Job created: $jobName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger cron job: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Toggles the suspend state of the cron job
  Future<void> _toggleSuspend(bool currentSuspendState) async {
    try {
      final action = currentSuspendState ? 'Resuming' : 'Suspending';

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
                Text('$action cron job...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Toggle the suspend state
      final newSuspendState = await CronJobService.toggleCronJobSuspend(
        widget.kubernetesClient,
        widget.namespace,
        widget.cronJobName,
        currentSuspendState,
      );

      // Show success message
      if (mounted) {
        final status = newSuspendState ? 'suspended' : 'resumed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CronJob $status successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle suspend state: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Shows a confirmation dialog before deleting the cron job
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Delete CronJob'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this cron job?',
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
                          'CronJob Details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.cronJobName}', style: const TextStyle(fontSize: 12)),
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
                await _deleteCronJob();
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

  /// Deletes the cron job and navigates back
  Future<void> _deleteCronJob() async {
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
                Text('Deleting cron job...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Delete the cron job
      await CronJobService.deleteCronJob(
        widget.kubernetesClient,
        widget.namespace,
        widget.cronJobName,
      );

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CronJob "${widget.cronJobName}" deleted successfully'),
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
            content: Text('Failed to delete cron job: $e'),
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
            const Text('Error loading cron job details'),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _cronJobDetailsSubscription?.cancel();
                _startWatchingCronJobDetails();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_cronJobDetails == null) {
      return const Center(
        child: Text('No cron job details available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildLabelsCard(),
          const SizedBox(height: 16),
          _buildJobHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final suspended = _cronJobDetails.spec?.suspend ?? false;

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
            _buildInfoRow(Icons.label_outline, 'Name', _cronJobDetails.metadata?.name ?? 'N/A'),
            _buildInfoRow(Icons.folder_outlined, 'Namespace', _cronJobDetails.metadata?.namespace ?? 'N/A'),
            _buildInfoRow(Icons.schedule, 'Schedule', _cronJobDetails.spec?.schedule ?? 'N/A'),
            _buildInfoRow(Icons.pause_circle_outline, 'Suspended', suspended ? 'Yes' : 'No',
              valueColor: suspended ? Colors.orange : Colors.green),
            _buildInfoRow(Icons.policy_outlined, 'Concurrency', _cronJobDetails.spec?.concurrencyPolicy ?? 'N/A'),
            _buildInfoRow(Icons.access_time, 'Created', _formatTimestamp(_cronJobDetails.metadata?.creationTimestamp)),
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

  Widget _buildStatusCard() {
    final activeJobs = _cronJobDetails.status?.active?.length ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
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
            _buildStatusRow(Icons.work_outline, 'Active Jobs', '$activeJobs',
              valueColor: activeJobs > 0 ? Colors.blue : null),
            _buildStatusRow(Icons.access_time, 'Last Schedule',
              _formatTimestamp(_cronJobDetails.status?.lastScheduleTime)),
            _buildStatusRow(Icons.check_circle_outline, 'Last Success',
              _formatTimestamp(_cronJobDetails.status?.lastSuccessfulTime)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
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
    if (timestamp == null) return 'Never';
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
    final labels = _cronJobDetails.metadata?.labels;

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

  /// Opens logs viewer using LogsManager
  void _openLogsTab(String jobName) {
    LogsManager().openLogs(
      id: 'logs-$jobName-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Logs: $jobName',
      kubernetesClient: widget.kubernetesClient,
      namespace: widget.namespace,
      jobName: jobName,
    );
  }

  Widget _buildJobHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Job History',
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
                    '${_jobs.length}',
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
            if (_jobs.isEmpty)
              Text(
                'No jobs found',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _jobs.length > 10 ? 10 : _jobs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return _buildJobItem(job);
                },
              ),
            if (_jobs.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing 10 of ${_jobs.length} jobs',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobItem(dynamic job) {
    final name = job.metadata?.name ?? 'Unknown';
    final creationTime = job.metadata?.creationTimestamp;
    final conditions = job.status?.conditions ?? [];

    // Determine job status
    String status = 'Running';
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.play_circle_outline;

    final succeeded = job.status?.succeeded ?? 0;
    final failed = job.status?.failed ?? 0;
    final active = job.status?.active ?? 0;

    if (succeeded > 0) {
      status = 'Succeeded';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (failed > 0) {
      status = 'Failed';
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else if (active > 0) {
      status = 'Running';
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle_outline;
    } else {
      // Check conditions for more details
      for (var condition in conditions) {
        if (condition.type == 'Complete' && condition.status == 'True') {
          status = 'Completed';
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_outline;
          break;
        } else if (condition.type == 'Failed' && condition.status == 'True') {
          status = 'Failed';
          statusColor = Colors.red;
          statusIcon = Icons.error_outline;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(creationTime),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Logs button
          IconButton(
            icon: const Icon(Icons.article_outlined, size: 18),
            tooltip: 'View logs',
            onPressed: () => _openLogsTab(name),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

