/// Model class representing Kubernetes Pod metrics (CPU and memory usage)
class PodMetrics {
  final String podName;
  final String namespace;
  final DateTime timestamp;
  final List<ContainerMetrics> containers;

  PodMetrics({
    required this.podName,
    required this.namespace,
    required this.timestamp,
    required this.containers,
  });

  /// Creates PodMetrics from Kubernetes metrics API response
  factory PodMetrics.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final podName = metadata?['name'] as String? ?? 'Unknown';
    final namespace = metadata?['namespace'] as String? ?? 'default';

    final timestampStr = json['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.parse(timestampStr)
        : DateTime.now();

    final containersList = json['containers'] as List<dynamic>? ?? [];
    final containers = containersList.map((c) {
      return ContainerMetrics.fromJson(c as Map<String, dynamic>);
    }).toList();

    return PodMetrics(
      podName: podName,
      namespace: namespace,
      timestamp: timestamp,
      containers: containers,
    );
  }

  /// Creates PodMetrics from kubectl top output
  factory PodMetrics.fromKubectlTop({
    required String podName,
    required String namespace,
    required String cpuStr,
    required String memoryStr,
  }) {
    // Parse CPU and memory from kubectl top format
    final cpuMillicores = ContainerMetrics.parseCpu(cpuStr);
    final memoryBytes = ContainerMetrics.parseMemory(memoryStr);

    // Create a single container metrics representing the whole pod
    final container = ContainerMetrics(
      name: 'total',
      cpuMillicores: cpuMillicores,
      memoryBytes: memoryBytes,
    );

    return PodMetrics(
      podName: podName,
      namespace: namespace,
      timestamp: DateTime.now(),
      containers: [container],
    );
  }

  /// Gets total CPU usage across all containers in millicores
  int get totalCpuMillicores {
    return containers.fold(0, (sum, container) => sum + container.cpuMillicores);
  }

  /// Gets total memory usage across all containers in bytes
  int get totalMemoryBytes {
    return containers.fold(0, (sum, container) => sum + container.memoryBytes);
  }

  /// Gets total memory usage in megabytes
  double get totalMemoryMB {
    return totalMemoryBytes / (1024 * 1024);
  }

  /// Gets total CPU usage in cores (e.g., 0.5 cores)
  double get totalCpuCores {
    return totalCpuMillicores / 1000.0;
  }
}

/// Model class representing metrics for a single container
class ContainerMetrics {
  final String name;
  final int cpuMillicores;
  final int memoryBytes;

  ContainerMetrics({
    required this.name,
    required this.cpuMillicores,
    required this.memoryBytes,
  });

  /// Creates ContainerMetrics from Kubernetes metrics API response
  factory ContainerMetrics.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unknown';
    
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    
    // Parse CPU (format: "250m" for 250 millicores or "1" for 1 core)
    final cpuStr = usage['cpu'] as String? ?? '0';
    final cpuMillicores = parseCpu(cpuStr);

    // Parse memory (format: "128Mi" or "134217728" bytes)
    final memoryStr = usage['memory'] as String? ?? '0';
    final memoryBytes = parseMemory(memoryStr);

    return ContainerMetrics(
      name: name,
      cpuMillicores: cpuMillicores,
      memoryBytes: memoryBytes,
    );
  }

  /// Parses CPU string to millicores
  static int parseCpu(String cpuStr) {
    if (cpuStr.endsWith('m')) {
      // Already in millicores (e.g., "250m")
      return int.tryParse(cpuStr.substring(0, cpuStr.length - 1)) ?? 0;
    } else if (cpuStr.endsWith('n')) {
      // Nanocores (e.g., "250000n" = 0.25m)
      final nanocores = int.tryParse(cpuStr.substring(0, cpuStr.length - 1)) ?? 0;
      return (nanocores / 1000000).round();
    } else {
      // Cores (e.g., "1" = 1000m)
      final cores = double.tryParse(cpuStr) ?? 0;
      return (cores * 1000).round();
    }
  }

  /// Parses memory string to bytes
  static int parseMemory(String memoryStr) {
    if (memoryStr.endsWith('Ki')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value * 1024;
    } else if (memoryStr.endsWith('Mi')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value * 1024 * 1024;
    } else if (memoryStr.endsWith('Gi')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 2)) ?? 0;
      return value * 1024 * 1024 * 1024;
    } else if (memoryStr.endsWith('k')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 1)) ?? 0;
      return value * 1000;
    } else if (memoryStr.endsWith('M')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 1)) ?? 0;
      return value * 1000 * 1000;
    } else if (memoryStr.endsWith('G')) {
      final value = int.tryParse(memoryStr.substring(0, memoryStr.length - 1)) ?? 0;
      return value * 1000 * 1000 * 1000;
    } else {
      // Already in bytes
      return int.tryParse(memoryStr) ?? 0;
    }
  }

  /// Gets memory usage in megabytes
  double get memoryMB {
    return memoryBytes / (1024 * 1024);
  }

  /// Gets CPU usage in cores
  double get cpuCores {
    return cpuMillicores / 1000.0;
  }
}

