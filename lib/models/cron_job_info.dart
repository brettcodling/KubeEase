/// Model class representing a Kubernetes CronJob
class CronJobInfo {
  final String name;
  final String namespace;
  final String schedule;
  final bool suspended;
  final int? activeJobs;
  final String? lastScheduleTime;
  final String? age;

  CronJobInfo({
    required this.name,
    required this.namespace,
    required this.schedule,
    required this.suspended,
    this.activeJobs,
    this.lastScheduleTime,
    this.age,
  });

  /// Factory constructor to create CronJobInfo from Kubernetes API response
  factory CronJobInfo.fromK8sCronJob(dynamic cronJob) {
    // Extract cron job metadata
    final name = cronJob.metadata?.name ?? 'Unknown';
    final namespace = cronJob.metadata?.namespace ?? 'default';
    
    // Extract spec details
    final schedule = cronJob.spec?.schedule ?? 'Unknown';
    final suspended = cronJob.spec?.suspend ?? false;
    
    // Extract status details
    final activeJobs = cronJob.status?.active?.length ?? 0;
    
    // Extract last schedule time
    String? lastScheduleTime;
    if (cronJob.status?.lastScheduleTime != null) {
      try {
        final lastSchedule = cronJob.status!.lastScheduleTime;
        final DateTime scheduleTime;
        
        if (lastSchedule is DateTime) {
          scheduleTime = lastSchedule;
        } else if (lastSchedule is String) {
          scheduleTime = DateTime.parse(lastSchedule);
        } else {
          scheduleTime = DateTime.now();
        }
        
        final now = DateTime.now();
        final difference = now.difference(scheduleTime);
        
        if (difference.inDays > 0) {
          lastScheduleTime = '${difference.inDays}d ago';
        } else if (difference.inHours > 0) {
          lastScheduleTime = '${difference.inHours}h ago';
        } else if (difference.inMinutes > 0) {
          lastScheduleTime = '${difference.inMinutes}m ago';
        } else {
          lastScheduleTime = '${difference.inSeconds}s ago';
        }
      } catch (e) {
        lastScheduleTime = null;
      }
    }
    
    // Calculate age
    String? age;
    if (cronJob.metadata?.creationTimestamp != null) {
      try {
        final creationTimestamp = cronJob.metadata!.creationTimestamp;
        final DateTime creationTime;
        
        if (creationTimestamp is DateTime) {
          creationTime = creationTimestamp;
        } else if (creationTimestamp is String) {
          creationTime = DateTime.parse(creationTimestamp);
        } else {
          creationTime = DateTime.now();
        }
        
        final now = DateTime.now();
        final difference = now.difference(creationTime);
        
        if (difference.inDays > 0) {
          age = '${difference.inDays}d';
        } else if (difference.inHours > 0) {
          age = '${difference.inHours}h';
        } else if (difference.inMinutes > 0) {
          age = '${difference.inMinutes}m';
        } else {
          age = '${difference.inSeconds}s';
        }
      } catch (e) {
        age = null;
      }
    }
    
    return CronJobInfo(
      name: name,
      namespace: namespace,
      schedule: schedule,
      suspended: suspended,
      activeJobs: activeJobs,
      lastScheduleTime: lastScheduleTime,
      age: age,
    );
  }
}

