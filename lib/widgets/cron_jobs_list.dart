import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/cron_job_info.dart';
import '../screens/cron_job_detail_screen.dart';

/// Widget that displays a list of Kubernetes cron jobs
class CronJobsList extends StatelessWidget {
  const CronJobsList({
    super.key,
    required this.cronJobs,
    required this.isLoading,
    required this.kubernetesClient,
    required this.onPauseWatching,
    required this.onResumeWatching,
  });

  final List<CronJobInfo> cronJobs;
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
            Text('Loading cron jobs...'),
          ],
        ),
      );
    }

    if (cronJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No cron jobs found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: cronJobs.length,
      itemBuilder: (context, index) {
        final cronJob = cronJobs[index];
        return _buildCronJobCard(context, cronJob);
      },
    );
  }

  /// Builds a card widget for a single cron job
  Widget _buildCronJobCard(BuildContext context, CronJobInfo cronJob) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Pause watching while viewing detail screen
          onPauseWatching();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CronJobDetailScreen(
                cronJobName: cronJob.name,
                namespace: cronJob.namespace,
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
            // Cron job name and status
            Row(
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cronJob.suspended
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Cron job name
                Expanded(
                  child: Text(
                    cronJob.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Age badge
                if (cronJob.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cronJob.age!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Cron job details
            _buildDetailRow(context, 'Namespace', cronJob.namespace),
            _buildDetailRow(context, 'Schedule', cronJob.schedule),
            _buildDetailRow(context, 'Status', cronJob.suspended ? 'Suspended' : 'Active'),
            _buildDetailRow(context, 'Active Jobs', '${cronJob.activeJobs ?? 0}'),
            if (cronJob.lastScheduleTime != null)
              _buildDetailRow(context, 'Last Schedule', cronJob.lastScheduleTime!),
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

