import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/service_info.dart';
import '../connection_error_manager.dart';
import '../auth_refresh_manager.dart';

/// Service class that handles all Service-related Kubernetes API interactions
class ServiceService {
  /// Fetches detailed information about a specific service
  static Future<dynamic> getServiceDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String serviceName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      final response = await coreV1Api.readNamespacedService(
        name: serviceName,
        namespace: namespace,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching service details: $e');
      rethrow;
    }
  }

  /// Watches a specific service for updates using periodic polling.
  static Stream<dynamic> watchServiceDetails(
    Kubernetes kubernetesClient,
    String namespace,
    String serviceName,
  ) {
    late StreamController<dynamic> controller;
    Timer? timer;

    void poll() async {
      if (!ConnectionErrorManager().isConnected) return;
      try {
        final client = AuthRefreshManager().currentClient ?? kubernetesClient;
        final updatedService = await getServiceDetails(client, namespace, serviceName);
        if (!controller.isClosed) controller.add(updatedService);
      } catch (e) {
        debugPrint('Error polling for service detail updates: $e');
        if (await AuthRefreshManager().checkAndRefreshIfNeeded(e)) return;
        if (ConnectionErrorManager().reportConnectionError(e)) return;
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<dynamic>(
      onListen: () async {
        try {
          final service = await getServiceDetails(AuthRefreshManager().currentClient ?? kubernetesClient, namespace, serviceName);
          if (!controller.isClosed) controller.add(service);
        } catch (e) {
          debugPrint('Error fetching initial service details: $e');
          if (!ConnectionErrorManager().reportConnectionError(e)) {
            if (!controller.isClosed) controller.addError(e);
          }
        }
        timer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Fetches services from the specified namespaces
  static Future<List<ServiceInfo>> fetchServices(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) async {
    try {
      final allServices = <ServiceInfo>[];
      final coreV1Api = kubernetesClient.client.getCoreV1Api();

      for (var namespace in namespaces) {
        final response = await coreV1Api.listNamespacedService(namespace: namespace);

        response.data?.items.forEach((service) {
          final serviceInfo = ServiceInfo.fromK8sService(service);
          allServices.add(serviceInfo);
        });
      }

      return allServices;
    } catch (e) {
      debugPrint('Error fetching services: $e');
      rethrow; // Rethrow to allow connection error detection
    }
  }

  /// Watches services from the specified namespaces using periodic polling.
  static Stream<List<ServiceInfo>> watchServices(
    Kubernetes kubernetesClient,
    Set<String> namespaces,
  ) {
    late StreamController<List<ServiceInfo>> controller;
    Timer? timer;
    List<ServiceInfo> currentServices = [];

    void poll() async {
      if (!ConnectionErrorManager().isConnected) return;
      try {
        final client = AuthRefreshManager().currentClient ?? kubernetesClient;
        final updatedServices = await fetchServices(client, namespaces);
        if (_servicesHaveChanged(currentServices, updatedServices)) {
          currentServices = updatedServices;
          if (!controller.isClosed) controller.add(updatedServices);
        }
      } catch (e) {
        debugPrint('Error polling for service updates: $e');
        if (await AuthRefreshManager().checkAndRefreshIfNeeded(e)) return;
        if (ConnectionErrorManager().reportConnectionError(e)) return;
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<ServiceInfo>>(
      onListen: () async {
        try {
          currentServices = await fetchServices(AuthRefreshManager().currentClient ?? kubernetesClient, namespaces);
          if (!controller.isClosed) controller.add(currentServices);
        } catch (e) {
          debugPrint('Error fetching initial services: $e');
          if (!ConnectionErrorManager().reportConnectionError(e)) {
            if (!controller.isClosed) controller.addError(e);
          }
        }
        timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Helper method to check if the service list has changed
  static bool _servicesHaveChanged(List<ServiceInfo> oldServices, List<ServiceInfo> newServices) {
    if (oldServices.length != newServices.length) return true;

    for (int i = 0; i < oldServices.length; i++) {
      final oldService = oldServices[i];
      final newService = newServices[i];

      if (oldService.name != newService.name ||
          oldService.namespace != newService.namespace ||
          oldService.clusterIP != newService.clusterIP ||
          oldService.ports != newService.ports ||
          oldService.age != newService.age) {
        return true;
      }
    }

    return false;
  }

  /// Delete a service
  static Future<void> deleteService(
    Kubernetes kubernetesClient,
    String namespace,
    String serviceName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      await coreV1Api.deleteNamespacedService(name: serviceName, namespace: namespace);
    } catch (e) {
      throw Exception('Failed to delete service: $e');
    }
  }
}
