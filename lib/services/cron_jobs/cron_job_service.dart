import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/cron_job_info.dart';
import '../connection_error_manager.dart';

/// Service class that handles all CronJob-related Kubernetes API interactions
class CronJobService {
  /// Fetches detailed information about a specific cron job
  static Future<dynamic> getCronJobDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
  ) async {
    try {
      final batchV1Api = kubernetesClient.client.getBatchV1Api();
      final response = await batchV1Api.readNamespacedCronJob(
        name: cronJobName,
        namespace: namespace,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching cron job details: $e');
      rethrow;
    }
  }

  /// Watches a specific cron job for updates using periodic polling
  static Stream<dynamic> watchCronJobDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
  ) {
    late StreamController<dynamic> controller;
    Timer? timer;
    dynamic currentCronJob;

    void poll() async {
      try {
        final updatedCronJob = await getCronJobDetails(kubernetesClient, namespace, cronJobName);

        // Always emit updates for detail views (user wants to see changes)
        currentCronJob = updatedCronJob;
        if (!controller.isClosed) {
          controller.add(updatedCronJob);
        }
      } catch (e) {
        debugPrint('Error polling for cron job detail updates: $e');

        // Check if this is a connection error
        if (ConnectionErrorManager().checkAndHandleError(e)) {
          timer?.cancel();
          controller.close();
          return;
        }

        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<dynamic>(
      onListen: () async {
        try {
          currentCronJob = await getCronJobDetails(kubernetesClient, namespace, cronJobName);
          if (!controller.isClosed) {
            controller.add(currentCronJob);
          }
        } catch (e) {
          debugPrint('Error fetching initial cron job details: $e');

          // Check if this is a connection error
          if (ConnectionErrorManager().checkAndHandleError(e)) {
            controller.close();
            return;
          }

          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Poll every 3 seconds
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());

        // Register cancel callback
        ConnectionErrorManager().registerWatcherCancelCallback(() {
          timer?.cancel();
          controller.close();
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Fetches cron jobs from the specified namespaces
  static Future<List<CronJobInfo>> fetchCronJobs(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) async {
    try {
      final allCronJobs = <CronJobInfo>[];
      final batchV1Api = kubernetesClient.client.getBatchV1Api();

      for (var namespace in namespaces) {
        final response = await batchV1Api.listNamespacedCronJob(namespace: namespace);

        response.data?.items.forEach((cronJob) {
          final cronJobInfo = CronJobInfo.fromK8sCronJob(cronJob);
          allCronJobs.add(cronJobInfo);
        });
      }

      return allCronJobs;
    } catch (e) {
      debugPrint('Error fetching cron jobs: $e');
      rethrow; // Rethrow to allow connection error detection
    }
  }

  /// Watches cron jobs from the specified namespaces using periodic polling
  /// Returns a stream that emits the complete list of cron jobs whenever changes occur
  static Stream<List<CronJobInfo>> watchCronJobs(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) {
    late StreamController<List<CronJobInfo>> controller;
    Timer? timer;
    List<CronJobInfo> currentCronJobs = [];

    void poll() async {
      try {
        // Fetch updated cron jobs
        final updatedCronJobs = await fetchCronJobs(kubernetesClient, namespaces);

        // Only emit if the list has changed
        if (_cronJobsHaveChanged(currentCronJobs, updatedCronJobs)) {
          currentCronJobs = updatedCronJobs;
          if (!controller.isClosed) {
            controller.add(updatedCronJobs);
          }
        }
      } catch (e) {
        debugPrint('Error polling for cron job updates: $e');

        // Check if this is a connection error
        if (ConnectionErrorManager().checkAndHandleError(e)) {
          timer?.cancel();
          controller.close();
          return;
        }

        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<List<CronJobInfo>>(
      onListen: () async {
        // Emit initial list of cron jobs
        try {
          currentCronJobs = await fetchCronJobs(kubernetesClient, namespaces);
          if (!controller.isClosed) {
            controller.add(currentCronJobs);
          }
        } catch (e) {
          debugPrint('Error fetching initial cron jobs: $e');

          // Check if this is a connection error
          if (ConnectionErrorManager().checkAndHandleError(e)) {
            controller.close();
            return;
          }

          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Start periodic polling (every 3 seconds)
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());

        // Register cancel callback
        ConnectionErrorManager().registerWatcherCancelCallback(() {
          timer?.cancel();
          controller.close();
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Helper method to check if the cron job list has changed
  static bool _cronJobsHaveChanged(List<CronJobInfo> oldCronJobs, List<CronJobInfo> newCronJobs) {
    // Quick check: different lengths means changed
    if (oldCronJobs.length != newCronJobs.length) {
      return true;
    }

    // Create maps for efficient lookup
    final oldCronJobMap = {for (var cronJob in oldCronJobs) '${cronJob.namespace}/${cronJob.name}': cronJob};
    final newCronJobMap = {for (var cronJob in newCronJobs) '${cronJob.namespace}/${cronJob.name}': cronJob};

    // Check if any cron job has changed
    for (var key in newCronJobMap.keys) {
      final oldCronJob = oldCronJobMap[key];
      final newCronJob = newCronJobMap[key];

      if (oldCronJob == null) {
        // New cron job added
        return true;
      }

      // Check if any relevant fields have changed
      if (oldCronJob.schedule != newCronJob?.schedule ||
          oldCronJob.suspended != newCronJob?.suspended ||
          oldCronJob.activeJobs != newCronJob?.activeJobs ||
          oldCronJob.age != newCronJob?.age) {
        return true;
      }
    }

    return false;
  }

  /// Delete a cron job
  static Future<void> deleteCronJob(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
  ) async {
    try {
      final batchV1Api = kubernetesClient.client.getBatchV1Api();
      await batchV1Api.deleteNamespacedCronJob(name: cronJobName, namespace: namespace);
    } catch (e) {
      throw Exception('Failed to delete cron job: $e');
    }
  }

  /// Trigger a cron job manually by creating a Job from it
  static Future<String> triggerCronJob(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
  ) async {
    try {
      final batchV1Api = kubernetesClient.client.getBatchV1Api();

      // Get the CronJob to access its job template
      final cronJobResponse = await batchV1Api.readNamespacedCronJob(
        name: cronJobName,
        namespace: namespace,
      );

      final cronJob = cronJobResponse.data;
      if (cronJob == null || cronJob.spec?.jobTemplate == null) {
        throw Exception('CronJob not found or has no job template');
      }

      // Create a unique job name based on the cron job name and timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jobName = '$cronJobName-manual-$timestamp';

      // Create a Job from the CronJob's template
      final job = V1Job(
        metadata: V1ObjectMeta(
          name: jobName,
          namespace: namespace,
          labels: {
            'cronjob-name': cronJobName,
            'manual-trigger': 'true',
            ...(cronJob.spec?.jobTemplate.metadata?.labels ?? {}),
          },
        ),
        spec: cronJob.spec?.jobTemplate.spec,
      );

      // Create the job
      await batchV1Api.createNamespacedJob(
        namespace: namespace,
        body: job,
      );

      return jobName;
    } catch (e) {
      debugPrint('Error triggering cron job: $e');
      throw Exception('Failed to trigger cron job: $e');
    }
  }

  /// Toggle suspend state of a cron job
  static Future<bool> toggleCronJobSuspend(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
    bool currentSuspendState,
  ) async {
    try {
      final batchV1Api = kubernetesClient.client.getBatchV1Api();

      // Read the current CronJob
      final cronJobResponse = await batchV1Api.readNamespacedCronJob(
        name: cronJobName,
        namespace: namespace,
      );

      final cronJob = cronJobResponse.data;
      if (cronJob == null || cronJob.spec == null) {
        throw Exception('CronJob not found');
      }

      // Create a new spec with the updated suspend state
      final newSpec = V1CronJobSpec(
        schedule: cronJob.spec!.schedule,
        suspend: !currentSuspendState,
        jobTemplate: cronJob.spec!.jobTemplate,
        concurrencyPolicy: cronJob.spec!.concurrencyPolicy,
        successfulJobsHistoryLimit: cronJob.spec!.successfulJobsHistoryLimit,
        failedJobsHistoryLimit: cronJob.spec!.failedJobsHistoryLimit,
        startingDeadlineSeconds: cronJob.spec!.startingDeadlineSeconds,
      );

      // Create a new CronJob object with the updated spec
      final updatedCronJob = V1CronJob(
        metadata: cronJob.metadata,
        spec: newSpec,
      );

      // Replace the CronJob
      await batchV1Api.replaceNamespacedCronJob(
        name: cronJobName,
        namespace: namespace,
        body: updatedCronJob,
      );

      return !currentSuspendState;
    } catch (e) {
      debugPrint('Error toggling cron job suspend state: $e');
      throw Exception('Failed to toggle cron job suspend state: $e');
    }
  }

  /// Fetch jobs created by a specific CronJob
  static Future<List<dynamic>> fetchJobsForCronJob(
    Kubernetes kubernetesClient,
    String namespace,
    String cronJobName,
  ) async {
    try {
      final batchV1Api = kubernetesClient.client.getBatchV1Api();

      // List all jobs in the namespace
      final jobsResponse = await batchV1Api.listNamespacedJob(namespace: namespace);

      final jobs = jobsResponse.data?.items ?? [];

      // Filter jobs that belong to this CronJob
      final cronJobJobs = jobs.where((job) {
        // Check if the job has an owner reference to this CronJob
        final ownerReferences = job.metadata?.ownerReferences ?? [];
        final hasOwnerReference = ownerReferences.any((ref) =>
            ref.kind == 'CronJob' && ref.name == cronJobName);

        // Also check for manual triggers with the cronjob-name label
        final labels = job.metadata?.labels ?? {};
        final hasLabel = labels['cronjob-name'] == cronJobName;

        return hasOwnerReference || hasLabel;
      }).toList();

      // Sort by creation time (newest first)
      cronJobJobs.sort((a, b) {
        final aTime = a.metadata?.creationTimestamp;
        final bTime = b.metadata?.creationTimestamp;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return cronJobJobs;
    } catch (e) {
      debugPrint('Error fetching jobs for CronJob: $e');
      return [];
    }
  }
}


