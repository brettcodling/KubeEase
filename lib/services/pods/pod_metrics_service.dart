import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../../models/pod_metrics.dart';

/// Service class that handles Pod metrics API interactions
class PodMetricsService {
  /// Fetches current metrics for a specific pod
  static Future<PodMetrics?> getPodMetrics(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) async {
    try {
      // Use kubectl to get per-container metrics
      final result = await Process.run(
        'kubectl',
        ['top', 'pod', podName, '-n', namespace, '--containers', '--no-headers'],
      );

      if (result.exitCode == 0) {
        // Parse kubectl top output with --containers flag
        // Format: "pod-name   container-name   CPU(cores)   MEMORY(bytes)"
        // Example:
        // "my-pod   container1   250m   128Mi"
        // "my-pod   container2   100m   64Mi"
        final output = result.stdout.toString().trim();
        if (output.isEmpty) return null;

        final lines = output.split('\n');
        final containers = <ContainerMetrics>[];

        for (final line in lines) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length < 4) continue;

          final containerName = parts[1]; // Container name
          final cpuStr = parts[2]; // e.g., "250m"
          final memoryStr = parts[3]; // e.g., "128Mi"

          final cpuMillicores = ContainerMetrics.parseCpu(cpuStr);
          final memoryBytes = ContainerMetrics.parseMemory(memoryStr);

          containers.add(ContainerMetrics(
            name: containerName,
            cpuMillicores: cpuMillicores,
            memoryBytes: memoryBytes,
          ));
        }

        if (containers.isEmpty) return null;

        return PodMetrics(
          podName: podName,
          namespace: namespace,
          timestamp: DateTime.now(),
          containers: containers,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching pod metrics: $e');
      // Metrics might not be available (requires metrics-server)
      return null;
    }
  }

  /// Watches pod metrics using periodic polling
  /// Returns a stream that emits metrics data every 10 seconds
  static Stream<PodMetrics?> watchPodMetrics(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
  ) {
    late StreamController<PodMetrics?> controller;
    Timer? timer;

    controller = StreamController<PodMetrics?>(
      onListen: () {
        // Fetch immediately on listen
        _fetchAndEmitMetrics(kubernetesClient, namespace, podName, controller);

        // Then poll every 10 seconds
        timer = Timer.periodic(const Duration(seconds: 10), (_) {
          _fetchAndEmitMetrics(kubernetesClient, namespace, podName, controller);
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  static Future<void> _fetchAndEmitMetrics(
    Kubernetes kubernetesClient,
    String namespace,
    String podName,
    StreamController<PodMetrics?> controller,
  ) async {
    try {
      final metrics = await getPodMetrics(kubernetesClient, namespace, podName);
      if (!controller.isClosed) {
        controller.add(metrics);
      }
    } catch (e) {
      debugPrint('Error in metrics polling: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }
}

