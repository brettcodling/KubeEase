import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/secret_info.dart';
import '../connection_error_manager.dart';
import '../auth_refresh_manager.dart';

/// Service class that handles all Secret-related Kubernetes API interactions
class SecretService {
  /// Fetches detailed information about a specific secret
  static Future<dynamic> getSecretDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String secretName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      final response = await coreV1Api.readNamespacedSecret(
        name: secretName,
        namespace: namespace,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching secret details: $e');
      rethrow;
    }
  }

  /// Watches a specific secret for updates using periodic polling
  static Stream<dynamic> watchSecretDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String secretName,
  ) {
    late StreamController<dynamic> controller;
    Timer? timer;
    WatcherHandle? handle;
    dynamic currentSecret;
    bool isPaused = false;

    void poll() async {
      if (isPaused) return;
      try {
        final updatedSecret = await getSecretDetails(kubernetesClient, namespace, secretName);

        // Always emit updates for detail views (user wants to see changes)
        currentSecret = updatedSecret;
        if (!controller.isClosed) {
          controller.add(updatedSecret);
        }
      } catch (e) {
        debugPrint('Error polling for secret detail updates: $e');

        // Check if this is a 401 error (expired token) and trigger refresh
        final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
        if (wasAuthError) {
          // Token refresh was triggered
          return;
        }

        // Connection error: manager will pause us; data preserved.
        if (ConnectionErrorManager().checkAndHandleError(e)) {
          return;
        }

        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    void startPolling() {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
    }

    void stopPolling() {
      timer?.cancel();
      timer = null;
    }

    controller = StreamController<dynamic>(
      onListen: () async {
        try {
          currentSecret = await getSecretDetails(kubernetesClient, namespace, secretName);
          if (!controller.isClosed) {
            controller.add(currentSecret);
          }
        } catch (e) {
          debugPrint('Error fetching initial secret details: $e');

          if (!ConnectionErrorManager().checkAndHandleError(e)) {
            if (!controller.isClosed) {
              controller.addError(e);
            }
          }
        }

        startPolling();

        handle = ConnectionErrorManager().registerWatcher(
          pause: () {
            isPaused = true;
            stopPolling();
          },
          resume: () {
            isPaused = false;
            startPolling();
          },
        );
      },
      onCancel: () {
        stopPolling();
        ConnectionErrorManager().unregisterWatcher(handle);
        handle = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Fetches secrets from the specified namespaces
  static Future<List<SecretInfo>> fetchSecrets(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) async {
    try {
      final allSecrets = <SecretInfo>[];
      final coreV1Api = kubernetesClient.client.getCoreV1Api();

      for (var namespace in namespaces) {
        final response = await coreV1Api.listNamespacedSecret(namespace: namespace);

        response.data?.items.forEach((secret) {
          final secretInfo = SecretInfo.fromK8sSecret(secret);
          allSecrets.add(secretInfo);
        });
      }

      return allSecrets;
    } catch (e) {
      debugPrint('Error fetching secrets: $e');
      rethrow; // Rethrow to allow connection error detection
    }
  }

  /// Watches secrets from the specified namespaces using periodic polling
  /// Returns a stream that emits the complete list of secrets whenever changes occur
  static Stream<List<SecretInfo>> watchSecrets(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) {
    late StreamController<List<SecretInfo>> controller;
    Timer? timer;
    WatcherHandle? handle;
    List<SecretInfo> currentSecrets = [];
    bool isPaused = false;

    void poll() async {
      if (isPaused) return;
      try {
        // Fetch updated secrets
        final updatedSecrets = await fetchSecrets(kubernetesClient, namespaces);

        // Only emit if the list has changed
        if (_secretsHaveChanged(currentSecrets, updatedSecrets)) {
          currentSecrets = updatedSecrets;
          if (!controller.isClosed) {
            controller.add(updatedSecrets);
          }
        }
      } catch (e) {
        debugPrint('Error polling for secret updates: $e');

        // Check if this is a 401 error (expired token) and trigger refresh
        final wasAuthError = await AuthRefreshManager().checkAndRefreshIfNeeded(e);
        if (wasAuthError) {
          // Token refresh was triggered
          return;
        }

        // Connection error: manager will pause us; data preserved.
        if (ConnectionErrorManager().checkAndHandleError(e)) {
          return;
        }

        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    void startPolling() {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
    }

    void stopPolling() {
      timer?.cancel();
      timer = null;
    }

    controller = StreamController<List<SecretInfo>>(
      onListen: () async {
        // Emit initial list of secrets
        try {
          currentSecrets = await fetchSecrets(kubernetesClient, namespaces);
          if (!controller.isClosed) {
            controller.add(currentSecrets);
          }
        } catch (e) {
          debugPrint('Error fetching initial secrets: $e');

          if (!ConnectionErrorManager().checkAndHandleError(e)) {
            if (!controller.isClosed) {
              controller.addError(e);
            }
          }
        }

        startPolling();

        handle = ConnectionErrorManager().registerWatcher(
          pause: () {
            isPaused = true;
            stopPolling();
          },
          resume: () {
            isPaused = false;
            startPolling();
          },
        );
      },
      onCancel: () {
        stopPolling();
        ConnectionErrorManager().unregisterWatcher(handle);
        handle = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Helper method to check if the secret list has changed
  static bool _secretsHaveChanged(List<SecretInfo> oldSecrets, List<SecretInfo> newSecrets) {
    // Quick check: different lengths means changed
    if (oldSecrets.length != newSecrets.length) {
      return true;
    }

    // Create maps for efficient lookup
    final oldSecretMap = {for (var secret in oldSecrets) '${secret.namespace}/${secret.name}': secret};
    final newSecretMap = {for (var secret in newSecrets) '${secret.namespace}/${secret.name}': secret};

    // Check if any secret has changed
    for (var key in newSecretMap.keys) {
      final oldSecret = oldSecretMap[key];
      final newSecret = newSecretMap[key];

      if (oldSecret == null) {
        // New secret added
        return true;
      }

      // Check if any relevant fields have changed
      if (oldSecret.type != newSecret?.type ||
          oldSecret.dataCount != newSecret?.dataCount ||
          oldSecret.age != newSecret?.age) {
        return true;
      }
    }

    return false;
  }

  /// Delete a secret
  static Future<void> deleteSecret(
    Kubernetes kubernetesClient,
    String namespace,
    String secretName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      await coreV1Api.deleteNamespacedSecret(name: secretName, namespace: namespace);
    } catch (e) {
      throw Exception('Failed to delete secret: $e');
    }
  }
}


