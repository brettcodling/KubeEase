import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/deployment_info.dart';

/// Service class that handles Deployment-related Kubernetes API interactions
class DeploymentService {
  /// Gets the deployment name from a pod's owner references
  static String? getDeploymentFromPod(dynamic pod) {
    final ownerReferences = pod.metadata?.ownerReferences ?? [];
    
    // First check if pod is directly owned by a deployment
    for (var ref in ownerReferences) {
      if (ref.kind == 'Deployment') {
        return ref.name;
      }
    }
    
    // If owned by ReplicaSet, the deployment name is typically the ReplicaSet name without the hash suffix
    for (var ref in ownerReferences) {
      if (ref.kind == 'ReplicaSet') {
        final replicaSetName = ref.name;
        if (replicaSetName != null) {
          // Remove the hash suffix (last part after the last dash)
          final parts = replicaSetName.split('-');
          if (parts.length > 1) {
            // Remove the last part (hash) and rejoin
            return parts.sublist(0, parts.length - 1).join('-');
          }
        }
      }
    }
    
    return null;
  }

  /// Gets the current replica count of a deployment
  static Future<int?> getDeploymentReplicas(
    Kubernetes kubernetesClient,
    String namespace,
    String deploymentName,
  ) async {
    try {
      final appsV1Api = kubernetesClient.client.getAppsV1Api();
      final response = await appsV1Api.readNamespacedDeployment(
        name: deploymentName,
        namespace: namespace,
      );
      return response.data?.spec?.replicas;
    } catch (e) {
      debugPrint('Error fetching deployment replicas: $e');
      return null;
    }
  }

  /// Scales a deployment to the specified number of replicas
  static Future<void> scaleDeployment(
    Kubernetes kubernetesClient,
    String namespace,
    String deploymentName,
    int replicas,
  ) async {
    try {
      final appsV1Api = kubernetesClient.client.getAppsV1Api();

      // Read the current deployment
      final deploymentResponse = await appsV1Api.readNamespacedDeployment(
        name: deploymentName,
        namespace: namespace,
      );

      final deployment = deploymentResponse.data;
      if (deployment == null || deployment.spec == null) {
        throw Exception('Deployment not found');
      }

      // Create a new spec with the updated replica count
      final newSpec = V1DeploymentSpec(
        replicas: replicas,
        selector: deployment.spec!.selector,
        template: deployment.spec!.template,
        strategy: deployment.spec!.strategy,
        minReadySeconds: deployment.spec!.minReadySeconds,
        revisionHistoryLimit: deployment.spec!.revisionHistoryLimit,
        paused: deployment.spec!.paused,
        progressDeadlineSeconds: deployment.spec!.progressDeadlineSeconds,
      );

      // Create a new deployment with the updated spec
      final updatedDeployment = V1Deployment(
        metadata: deployment.metadata,
        spec: newSpec,
      );

      // Replace the deployment
      await appsV1Api.replaceNamespacedDeployment(
        name: deploymentName,
        namespace: namespace,
        body: updatedDeployment,
      );
    } catch (e) {
      debugPrint('Error scaling deployment: $e');
      rethrow;
    }
  }

  /// Fetches deployments from the specified namespaces
  static Future<List<DeploymentInfo>> fetchDeployments(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) async {
    try {
      final allDeployments = <DeploymentInfo>[];
      final appsV1Api = kubernetesClient.client.getAppsV1Api();

      for (var namespace in namespaces) {
        final response = await appsV1Api.listNamespacedDeployment(namespace: namespace);

        response.data?.items.forEach((deployment) {
          final deploymentInfo = DeploymentInfo.fromK8sDeployment(deployment);
          allDeployments.add(deploymentInfo);
        });
      }

      return allDeployments;
    } catch (e) {
      debugPrint('Error fetching deployments: $e');
      return [];
    }
  }

  /// Watches deployments from the specified namespaces using periodic polling
  /// Returns a stream that emits the complete list of deployments whenever changes occur
  static Stream<List<DeploymentInfo>> watchDeployments(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) {
    late StreamController<List<DeploymentInfo>> controller;
    Timer? timer;
    List<DeploymentInfo> currentDeployments = [];

    void poll() async {
      try {
        // Fetch updated deployments
        final updatedDeployments = await fetchDeployments(kubernetesClient, namespaces);

        // Only emit if the list has changed
        if (_deploymentsHaveChanged(currentDeployments, updatedDeployments)) {
          currentDeployments = updatedDeployments;
          if (!controller.isClosed) {
            controller.add(updatedDeployments);
          }
        }
      } catch (e) {
        debugPrint('Error polling for deployment updates: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<List<DeploymentInfo>>(
      onListen: () async {
        // Emit initial list of deployments
        try {
          currentDeployments = await fetchDeployments(kubernetesClient, namespaces);
          if (!controller.isClosed) {
            controller.add(currentDeployments);
          }
        } catch (e) {
          debugPrint('Error fetching initial deployments: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Start periodic polling (every 3 seconds)
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Helper method to check if deployments list has changed
  static bool _deploymentsHaveChanged(
    List<DeploymentInfo> oldList,
    List<DeploymentInfo> newList,
  ) {
    if (oldList.length != newList.length) return true;

    for (int i = 0; i < oldList.length; i++) {
      final oldDeployment = oldList[i];
      final newDeployment = newList[i];

      if (oldDeployment.name != newDeployment.name ||
          oldDeployment.namespace != newDeployment.namespace ||
          oldDeployment.replicas != newDeployment.replicas ||
          oldDeployment.readyReplicas != newDeployment.readyReplicas ||
          oldDeployment.availableReplicas != newDeployment.availableReplicas ||
          oldDeployment.updatedReplicas != newDeployment.updatedReplicas) {
        return true;
      }
    }

    return false;
  }

  /// Fetches detailed information about a specific deployment
  static Future<dynamic> getDeploymentDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String deploymentName,
  ) async {
    try {
      final appsV1Api = kubernetesClient.client.getAppsV1Api();
      final response = await appsV1Api.readNamespacedDeployment(
        name: deploymentName,
        namespace: namespace,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching deployment details: $e');
      rethrow;
    }
  }

  /// Watches a specific deployment for updates using periodic polling
  static Stream<dynamic> watchDeploymentDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String deploymentName,
  ) {
    late StreamController<dynamic> controller;
    Timer? timer;
    dynamic currentDeployment;

    void poll() async {
      try {
        final updatedDeployment = await getDeploymentDetails(kubernetesClient, namespace, deploymentName);

        // Always emit updates for detail views
        currentDeployment = updatedDeployment;
        if (!controller.isClosed) {
          controller.add(updatedDeployment);
        }
      } catch (e) {
        debugPrint('Error polling for deployment detail updates: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<dynamic>(
      onListen: () async {
        try {
          currentDeployment = await getDeploymentDetails(kubernetesClient, namespace, deploymentName);
          if (!controller.isClosed) {
            controller.add(currentDeployment);
          }
        } catch (e) {
          debugPrint('Error fetching initial deployment details: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Poll every 3 seconds
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }
}

