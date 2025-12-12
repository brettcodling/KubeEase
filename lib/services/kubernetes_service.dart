import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../exceptions/authentication_exception.dart';

/// Service class that handles common Kubernetes infrastructure operations
/// Resource-specific operations are in separate service classes:
/// - PodService for pod operations
/// - CronJobService for cron job operations
/// - SecretService for secret operations
class KubernetesService {
  /// Reads the kubeconfig file and initializes the Kubernetes client
  static Future<(Kubernetes, Kubeconfig)> initialize() async {
    // Read the kubeconfig file from the user's home directory
    final kubeconfigPath = '${Platform.environment['HOME']}/.kube/config';
    final kubeconfigYaml = await File(kubeconfigPath).readAsString();

    // Parse the YAML content into a Kubeconfig object
    final kubeconfig = Kubeconfig.fromYaml(kubeconfigYaml);

    // Initialize the Kubernetes client with default settings from kubeconfig
    final kubernetesClient = Kubernetes();
    try {
      await kubernetesClient.initDefault();
    } catch (e) {
      // Extract authentication plugin information from the error
      final errorMessage = e.toString();
      String? authPlugin;
      String? cloudPlatform;

      // Detect cloud platform based on auth plugin
      if (errorMessage.contains('gke-gcloud-auth-plugin')) {
        authPlugin = 'gke-gcloud-auth-plugin';
        cloudPlatform = 'Google Cloud (GKE)';
      } else if (errorMessage.contains('aws-iam-authenticator') || errorMessage.contains('eks')) {
        authPlugin = 'aws-iam-authenticator';
        cloudPlatform = 'Amazon Web Services (EKS)';
      } else if (errorMessage.contains('azure') || errorMessage.contains('aks')) {
        authPlugin = 'Azure CLI';
        cloudPlatform = 'Microsoft Azure (AKS)';
      } else if (errorMessage.contains('oidc') || errorMessage.contains('exec')) {
        authPlugin = 'authentication plugin';
        cloudPlatform = 'your cloud provider';
      }

      if (authPlugin != null && cloudPlatform != null) {
        throw AuthenticationException(
          'Authentication failed for $cloudPlatform',
          authPlugin,
          cloudPlatform,
          errorMessage,
        );
      }

      // Re-throw if we couldn't identify the auth plugin
      rethrow;
    }

    return (kubernetesClient, kubeconfig);
  }

  /// Loads the list of available contexts from the kubeconfig file
  static (List<String>, String) loadContexts(Kubeconfig kubeconfig) {
    final availableContexts = <String>[];
    
    // Extract context names from the kubeconfig
    if (kubeconfig.contexts != null) {
      for (var context in kubeconfig.contexts!) {
        if (context.name != null) {
          availableContexts.add(context.name!);
        }
      }
    }

    // Get the active context from kubeconfig
    final activeContext = kubeconfig.currentContext ?? '';
    
    return (availableContexts, activeContext);
  }

  /// Fetches the list of namespaces from the current Kubernetes context
  static Future<List<String>> loadNamespaces(Kubernetes kubernetesClient) async {
    try {
      // Get the Core V1 API client to interact with Kubernetes
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      
      // Fetch all namespaces from the cluster
      final allNamespaces = await coreV1Api.listNamespace();
      
      // Extract namespace names from the response
      final namespaceList = <String>[];
      allNamespaces.data?.items.forEach((namespace) {
        if (namespace.metadata?.name != null) {
          namespaceList.add(namespace.metadata?.name ?? '');
        }
      });
      
      return namespaceList;
    } catch (e) {
      debugPrint('Error loading namespaces: $e');
      return [];
    }
  }

  /// Watches namespaces using periodic polling
  /// Returns a stream that emits the complete list of namespaces whenever changes occur
  static Stream<List<String>> watchNamespaces(Kubernetes kubernetesClient) {
    late StreamController<List<String>> controller;
    Timer? timer;
    List<String> currentNamespaces = [];

    void poll() async {
      try {
        // Fetch updated namespaces
        final updatedNamespaces = await loadNamespaces(kubernetesClient);

        // Only emit if the list has changed
        if (_namespacesHaveChanged(currentNamespaces, updatedNamespaces)) {
          currentNamespaces = updatedNamespaces;
          if (!controller.isClosed) {
            controller.add(updatedNamespaces);
          }
        }
      } catch (e) {
        debugPrint('Error polling for namespace updates: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<List<String>>(
      onListen: () async {
        // Emit initial list of namespaces
        try {
          currentNamespaces = await loadNamespaces(kubernetesClient);
          if (!controller.isClosed) {
            controller.add(currentNamespaces);
          }
        } catch (e) {
          debugPrint('Error fetching initial namespaces: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }

        // Start periodic polling (every 5 seconds for namespaces)
        timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Helper method to check if the namespace list has changed
  static bool _namespacesHaveChanged(List<String> oldNamespaces, List<String> newNamespaces) {
    // Quick check: different lengths means changed
    if (oldNamespaces.length != newNamespaces.length) {
      return true;
    }

    // Check if all namespaces are the same
    final oldSet = oldNamespaces.toSet();
    final newSet = newNamespaces.toSet();

    return !oldSet.containsAll(newSet) || !newSet.containsAll(oldSet);
  }

  /// Switches to a different Kubernetes context and updates the kubeconfig file
  static Future<(Kubernetes, Kubeconfig)> switchContext(
    String contextName,
    Kubeconfig currentKubeconfig,
  ) async {
    // Update the current context in the kubeconfig object
    final updatedKubeconfig = currentKubeconfig.copyWith.currentContext(contextName);

    // Write the updated kubeconfig back to the file system
    final kubeconfigPath = '${Platform.environment['HOME']}/.kube/config';
    await File(kubeconfigPath).writeAsString(updatedKubeconfig.toYaml());

    // Reinitialize the Kubernetes client to use the new context
    final kubernetesClient = Kubernetes();
    try {
      await kubernetesClient.initDefault();
    } catch (e) {
      // Extract authentication plugin information from the error
      final errorMessage = e.toString();
      String? authPlugin;
      String? cloudPlatform;

      // Detect cloud platform based on auth plugin
      if (errorMessage.contains('gke-gcloud-auth-plugin')) {
        authPlugin = 'gke-gcloud-auth-plugin';
        cloudPlatform = 'Google Cloud (GKE)';
      } else if (errorMessage.contains('aws-iam-authenticator') || errorMessage.contains('eks')) {
        authPlugin = 'aws-iam-authenticator';
        cloudPlatform = 'Amazon Web Services (EKS)';
      } else if (errorMessage.contains('azure') || errorMessage.contains('aks')) {
        authPlugin = 'Azure CLI';
        cloudPlatform = 'Microsoft Azure (AKS)';
      } else if (errorMessage.contains('oidc') || errorMessage.contains('exec')) {
        authPlugin = 'authentication plugin';
        cloudPlatform = 'your cloud provider';
      }

      if (authPlugin != null && cloudPlatform != null) {
        throw AuthenticationException(
          'Authentication failed for $cloudPlatform',
          authPlugin,
          cloudPlatform,
          errorMessage,
        );
      }

      // Re-throw if we couldn't identify the auth plugin
      rethrow;
    }

    return (kubernetesClient, updatedKubeconfig);
  }
}

