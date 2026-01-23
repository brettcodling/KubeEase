import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/custom_resource_info.dart';
import '../connection_error_manager.dart';
import '../auth_refresh_manager.dart';

/// Service class that handles all Custom Resource-related Kubernetes API interactions
class CustomResourceService {
  /// Fetches all Custom Resource Definitions (CRDs) from the cluster
  static Future<List<CustomResourceDefinitionInfo>> fetchCRDs(
    Kubernetes kubernetesClient,
  ) async {
    try {
      // Use kubectl to fetch CRDs
      final result = await Process.run(
        'kubectl',
        ['get', 'crd', '-o', 'json'],
      );

      if (result.exitCode != 0) {
        throw Exception('Failed to fetch CRDs: ${result.stderr}');
      }

      final data = jsonDecode(result.stdout as String);
      final items = data['items'] as List<dynamic>? ?? [];

      final crds = <CustomResourceDefinitionInfo>[];
      for (var item in items) {
        final crd = CustomResourceDefinitionInfo.fromK8sCRD(item);
        // Include all CRDs (both namespaced and cluster-scoped)
        crds.add(crd);
      }

      return crds;
    } catch (e) {
      debugPrint('Error fetching CRDs: $e');
      rethrow;
    }
  }

  /// Fetches custom resources of a specific CRD from the specified namespaces
  static Future<List<CustomResourceInfo>> fetchCustomResources(
    Kubernetes kubernetesClient,
    CustomResourceDefinitionInfo crd,
    Set<String> namespaces,
  ) async {
    try {
      final allResources = <CustomResourceInfo>[];

      // Handle cluster-scoped resources differently
      if (crd.scope == 'Cluster') {
        try {
          // Fetch cluster-scoped resources (no namespace flag)
          final result = await Process.run(
            'kubectl',
            ['get', crd.plural, '-o', 'json'],
          );

          if (result.exitCode != 0) {
            debugPrint('Failed to fetch cluster-scoped ${crd.plural}: ${result.stderr}');
            return allResources;
          }

          final data = jsonDecode(result.stdout as String);
          final items = data['items'] as List<dynamic>? ?? [];

          for (var item in items) {
            final resourceInfo = CustomResourceInfo.fromK8sResource(item);
            // Only add resources that match the expected kind
            if (resourceInfo.kind == crd.kind) {
              allResources.add(resourceInfo);
            }
          }
        } catch (e) {
          debugPrint('Error fetching cluster-scoped custom resources: $e');
        }
      } else {
        // Handle namespaced resources
        for (var namespace in namespaces) {
          try {
            // Use kubectl to fetch custom resources
            final result = await Process.run(
              'kubectl',
              ['get', crd.plural, '-n', namespace, '-o', 'json'],
            );

            if (result.exitCode != 0) {
              debugPrint('Failed to fetch ${crd.plural} from namespace $namespace: ${result.stderr}');
              continue;
            }

            final data = jsonDecode(result.stdout as String);
            final items = data['items'] as List<dynamic>? ?? [];

            for (var item in items) {
              final resourceInfo = CustomResourceInfo.fromK8sResource(item);
              // Only add resources that match the expected kind
              if (resourceInfo.kind == crd.kind) {
                allResources.add(resourceInfo);
              }
            }
          } catch (e) {
            debugPrint('Error fetching custom resources from namespace $namespace: $e');
            // Continue with other namespaces even if one fails
          }
        }
      }

      return allResources;
    } catch (e) {
      debugPrint('Error fetching custom resources: $e');
      rethrow;
    }
  }

  /// Watches custom resources of a specific CRD using periodic polling
  static Stream<List<CustomResourceInfo>> watchCustomResources(
    Kubernetes kubernetesClient,
    CustomResourceDefinitionInfo crd,
    Set<String> namespaces,
  ) {
    late StreamController<List<CustomResourceInfo>> controller;
    Timer? timer;
    List<CustomResourceInfo> currentResources = [];
    bool isFirstFetch = true;

    void poll() async {
      try {
        // Fetch updated custom resources
        final updatedResources = await fetchCustomResources(
          kubernetesClient,
          crd,
          namespaces,
        );

        // Always emit on first fetch, then only emit if the list has changed
        if (isFirstFetch || _resourcesHaveChanged(currentResources, updatedResources)) {
          isFirstFetch = false;
          currentResources = updatedResources;
          if (!controller.isClosed) {
            controller.add(updatedResources);
          }
        }
      } catch (e) {
        debugPrint('Error polling for custom resource updates: $e');

        // Check if this is a 401 error (expired token) and trigger refresh
        final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
        if (wasAuthError) {
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

    controller = StreamController<List<CustomResourceInfo>>(
      onListen: () {
        // Initial fetch
        poll();

        // Start periodic polling (every 5 seconds)
        timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());

        // Register cancel callback with connection error manager
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

  /// Helper method to check if the resource list has changed
  static bool _resourcesHaveChanged(
    List<CustomResourceInfo> oldList,
    List<CustomResourceInfo> newList,
  ) {
    if (oldList.length != newList.length) return true;

    // Create sets of resource identifiers for comparison
    final oldSet = oldList.map((r) => '${r.namespace}/${r.name}').toSet();
    final newSet = newList.map((r) => '${r.namespace}/${r.name}').toSet();

    return !oldSet.containsAll(newSet) || !newSet.containsAll(oldSet);
  }

  /// Delete a custom resource
  static Future<void> deleteCustomResource(
    Kubernetes kubernetesClient,
    CustomResourceDefinitionInfo crd,
    String namespace,
    String resourceName,
  ) async {
    try {
      // Use kubectl to delete the custom resource
      // Use full resource type (plural.group) to avoid ambiguity
      final resourceType = crd.group.isEmpty
          ? crd.plural
          : '${crd.plural}.${crd.group}';

      final args = crd.scope == 'Cluster'
          ? ['delete', resourceType, resourceName]
          : ['delete', resourceType, resourceName, '-n', namespace];

      final result = await Process.run('kubectl', args);

      if (result.exitCode != 0) {
        throw Exception('Failed to delete ${crd.kind}: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to delete ${crd.kind}: $e');
    }
  }
}

