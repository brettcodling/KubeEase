import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/pod_info.dart';
import '../../models/pod_event.dart';
import '../connection_error_manager.dart';
import '../auth_refresh_manager.dart';

/// Service class that handles all Pod-related Kubernetes API interactions
class PodService {
  /// Fetches detailed information about a specific pod
  static Future<dynamic> getPodDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      final response = await coreV1Api.readNamespacedPod(
        name: podName,
        namespace: namespace,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching pod details: $e');
      rethrow;
    }
  }

  /// Watches a specific pod for updates using periodic polling
  static Stream<dynamic> watchPodDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) {
    late StreamController<dynamic> controller;
    Timer? timer;
    dynamic currentPod;

    void poll() async {
      try {
        final updatedPod = await getPodDetails(kubernetesClient, namespace, podName);

        // Always emit updates for detail views (user wants to see changes)
        currentPod = updatedPod;
        if (!controller.isClosed) {
          controller.add(updatedPod);
        }
      } catch (e) {
        debugPrint('Error polling for pod detail updates: $e');

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
          currentPod = await getPodDetails(kubernetesClient, namespace, podName);
          if (!controller.isClosed) {
            controller.add(currentPod);
          }
        } catch (e) {
          debugPrint('Error fetching initial pod details: $e');

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

  /// Fetches pods from the specified namespaces
  static Future<List<PodInfo>> fetchPods(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) async {
    try {
      final allPods = <PodInfo>[];
      final coreV1Api = kubernetesClient.client.getCoreV1Api();

      for (var namespace in namespaces) {
        final response = await coreV1Api.listNamespacedPod(namespace: namespace);

        response.data?.items.forEach((pod) {
          final podInfo = PodInfo.fromK8sPod(pod);
          allPods.add(podInfo);
        });
      }

      return allPods;
    } catch (e) {
      debugPrint('Error fetching pods: $e');
      rethrow; // Rethrow to allow connection error detection
    }
  }

  /// Watches pods from the specified namespaces using periodic polling
  /// Returns a stream that emits the complete list of pods whenever changes occur
  ///
  /// Note: The k8s Dart package doesn't properly support Kubernetes watch API streaming,
  /// so we use periodic polling as a reliable alternative. This provides near-real-time
  /// updates (every 3 seconds) which is sufficient for most use cases.
  static Stream<List<PodInfo>> watchPods(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) {
    late StreamController<List<PodInfo>> controller;
    Timer? timer;
    List<PodInfo> currentPods = [];

    void poll() async {
      try {
        // Fetch updated pods
        final updatedPods = await fetchPods(kubernetesClient, namespaces);

        // Only emit if the list has changed
        if (_podsHaveChanged(currentPods, updatedPods)) {
          currentPods = updatedPods;
          if (!controller.isClosed) {
            controller.add(updatedPods);
          }
        }
      } catch (e) {
        debugPrint('Error fetching pods: $e');

        // Check if this is a 401 error (expired token) and trigger refresh
        final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
        if (wasAuthError) {
          // Token refresh was triggered, the error will be retried automatically
          // after the client is refreshed in cluster_view_screen
          return;
        }

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

    controller = StreamController<List<PodInfo>>(
      onListen: () async {
        // Emit initial list of pods
        try {
          currentPods = await fetchPods(kubernetesClient, namespaces);
          if (!controller.isClosed) {
            controller.add(currentPods);
          }
        } catch (e) {
          debugPrint('Error fetching initial pods: $e');

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

  /// Helper method to check if the pod list has changed
  static bool _podsHaveChanged(List<PodInfo> oldPods, List<PodInfo> newPods) {
    // Quick check: different lengths means changed
    if (oldPods.length != newPods.length) {
      return true;
    }

    // Create maps for efficient lookup
    final oldPodMap = {for (var pod in oldPods) '${pod.namespace}/${pod.name}': pod};
    final newPodMap = {for (var pod in newPods) '${pod.namespace}/${pod.name}': pod};

    // Check if any pod has changed
    for (var key in newPodMap.keys) {
      final oldPod = oldPodMap[key];
      final newPod = newPodMap[key];

      if (oldPod == null) {
        // New pod added
        return true;
      }

      // Check if any relevant fields have changed
      if (oldPod.status != newPod?.status ||
          oldPod.restartCount != newPod?.restartCount ||
          oldPod.age != newPod?.age) {
        return true;
      }
    }

    return false;
  }

  /// Delete a pod
  static Future<void> deletePod(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      await coreV1Api.deleteNamespacedPod(name: podName, namespace: namespace);
    } catch (e) {
      throw Exception('Failed to delete pod: $e');
    }
  }

  /// Watch container environment variables for a specific container in a pod
  static Stream<List<dynamic>> watchContainerEnvVars(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
    String containerName,
  ) {
    late StreamController<List<dynamic>> controller;
    Timer? timer;

    controller = StreamController<List<dynamic>>(
      onListen: () {
        // Fetch immediately
        _fetchContainerEnvVars(
          kubernetesClient,
          namespace,
          podName,
          containerName,
          controller,
        );

        // Set up periodic refresh every 3 seconds
        timer = Timer.periodic(const Duration(seconds: 3), (_) {
          _fetchContainerEnvVars(
            kubernetesClient,
            namespace,
            podName,
            containerName,
            controller,
          );
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  static Future<void> _fetchContainerEnvVars(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
    String containerName,
    StreamController<List<dynamic>> controller,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      final podResponse = await coreV1Api.readNamespacedPod(
        name: podName,
        namespace: namespace,
      );

      final pod = podResponse.data;
      if (pod != null) {
        final containers = pod.spec?.containers ?? [];
        try {
          final container = containers.firstWhere(
            (c) => c.name == containerName,
          );

          // Get env vars from direct values
          final directEnvVars = container.env ?? [];

          // Get env vars from envFrom (ConfigMaps and Secrets)
          final envFrom = container.envFrom ?? [];
          final resolvedEnvVars = <Map<String, dynamic>>[];

          // Add direct env vars
          for (var envVar in directEnvVars) {
            resolvedEnvVars.add({
              'name': envVar.name,
              'value': envVar.value,
              'valueFrom': envVar.valueFrom,
            });
          }

          // Resolve envFrom (ConfigMaps and Secrets)
          for (var envFromSource in envFrom) {
            if (envFromSource.configMapRef != null) {
              final configMapName = envFromSource.configMapRef!.name;
              try {
                final configMapResponse = await coreV1Api.readNamespacedConfigMap(
                  name: configMapName!,
                  namespace: namespace,
                );
                final configMapData = configMapResponse.data?.data ?? {};
                for (var entry in configMapData.entries) {
                  resolvedEnvVars.add({
                    'name': entry.key,
                    'value': entry.value,
                    'source': 'ConfigMap: $configMapName',
                  });
                }
              } catch (e) {
                debugPrint('Error fetching ConfigMap $configMapName: $e');
              }
            } else if (envFromSource.secretRef != null) {
              final secretName = envFromSource.secretRef!.name;
              try {
                final secretResponse = await coreV1Api.readNamespacedSecret(
                  name: secretName!,
                  namespace: namespace,
                );
                final secretData = secretResponse.data?.data ?? {};
                for (var entry in secretData.entries) {
                  resolvedEnvVars.add({
                    'name': entry.key,
                    'value': entry.value, // This is base64 encoded
                    'source': 'Secret: $secretName',
                    'isSecret': true,
                  });
                }
              } catch (e) {
                debugPrint('Error fetching Secret $secretName: $e');
              }
            }
          }

          controller.add(resolvedEnvVars);
        } catch (e) {
          // Container not found
          debugPrint('Container not found: $e');
          controller.add([]);
        }
      }
    } catch (e) {
      debugPrint('Error fetching container env vars: $e');

      // Check if this is a 401 error (expired token) and trigger refresh
      final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
      if (wasAuthError) {
        // Token refresh was triggered, the error will be retried automatically
        return;
      }

      controller.addError(e);
    }
  }

  /// Fetches events for a specific pod
  static Future<List<PodEvent>> fetchPodEvents(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();

      // Fetch events using fieldSelector to filter by pod name
      final response = await coreV1Api.listNamespacedEvent(
        namespace: namespace,
        fieldSelector: 'involvedObject.name=$podName,involvedObject.kind=Pod',
      );

      final events = <PodEvent>[];
      response.data?.items.forEach((event) {
        events.add(PodEvent.fromK8sEvent(event));
      });

      // Sort events by timestamp (most recent first)
      events.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return a.timestamp!.compareTo(b.timestamp!);
      });

      return events;
    } catch (e) {
      debugPrint('Error fetching pod events: $e');
      return [];
    }
  }

  /// Watches events for a specific pod using periodic polling
  static Stream<List<PodEvent>> watchPodEvents(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) {
    late StreamController<List<PodEvent>> controller;
    Timer? timer;
    List<PodEvent> currentEvents = [];

    void poll() async {
      try {
        final updatedEvents = await fetchPodEvents(kubernetesClient, namespace, podName);

        // Only emit if the events have changed
        if (_eventsHaveChanged(currentEvents, updatedEvents)) {
          currentEvents = updatedEvents;
          if (!controller.isClosed) {
            controller.add(updatedEvents);
          }
        }
      } catch (e) {
        debugPrint('Error polling for pod events: $e');

        // Check if this is a 401 error (expired token) and trigger refresh
        final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
        if (wasAuthError) {
          // Token refresh was triggered
          return;
        }

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

    controller = StreamController<List<PodEvent>>(
      onListen: () async {
        try {
          currentEvents = await fetchPodEvents(kubernetesClient, namespace, podName);
          if (!controller.isClosed) {
            controller.add(currentEvents);
          }
        } catch (e) {
          debugPrint('Error fetching initial pod events: $e');

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

  /// Helper method to check if events have changed
  static bool _eventsHaveChanged(List<PodEvent> oldEvents, List<PodEvent> newEvents) {
    if (oldEvents.length != newEvents.length) return true;

    for (int i = 0; i < oldEvents.length; i++) {
      if (oldEvents[i].type != newEvents[i].type ||
          oldEvents[i].reason != newEvents[i].reason ||
          oldEvents[i].message != newEvents[i].message ||
          oldEvents[i].count != newEvents[i].count) {
        return true;
      }
    }

    return false;
  }
}
