/// Model class representing a Kubernetes Pod with essential information
class PodInfo {
  final String name;
  final String namespace;
  final String status;
  final int restartCount;
  final String? age;
  final List<String> containerNames;

  PodInfo({
    required this.name,
    required this.namespace,
    required this.status,
    required this.restartCount,
    this.age,
    required this.containerNames,
  });

  /// Creates a PodInfo from a Kubernetes V1Pod object
  factory PodInfo.fromK8sPod(dynamic pod) {
    // Extract pod name
    final name = pod.metadata?.name ?? 'Unknown';
    
    // Extract namespace
    final namespace = pod.metadata?.namespace ?? 'default';

    // Extract pod status (phase)
    // Check if pod is terminating (has deletionTimestamp)
    String status;
    if (pod.metadata?.deletionTimestamp != null) {
      status = 'Terminating';
    } else {
      status = pod.status?.phase ?? 'Unknown';
    }
    
    // Calculate total restart count from all containers
    int restartCount = 0;
    final containerStatuses = pod.status?.containerStatuses ?? [];
    for (var containerStatus in containerStatuses) {
      restartCount = restartCount + ((containerStatus.restartCount ?? 0) as int);
    }
    
    // Extract container names
    final containerNames = <String>[];
    final containers = pod.spec?.containers ?? [];
    for (var container in containers) {
      if (container.name != null) {
        containerNames.add(container.name!);
      }
    }
    
    // Calculate age from creation timestamp
    String? age;
    if (pod.metadata?.creationTimestamp != null) {
      try {
        final creationTimestamp = pod.metadata!.creationTimestamp;
        final DateTime creationTime;

        // Handle both DateTime and String types
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
    
    return PodInfo(
      name: name,
      namespace: namespace,
      status: status,
      restartCount: restartCount,
      age: age,
      containerNames: containerNames,
    );
  }
}

