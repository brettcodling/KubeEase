/// Model class representing a Kubernetes Service
class ServiceInfo {
  final String name;
  final String namespace;
  final String type;
  final String? clusterIP;
  final List<dynamic> ports;
  final String? age;

  ServiceInfo({
    required this.name,
    required this.namespace,
    required this.type,
    this.clusterIP,
    required this.ports,
    this.age,
  });

  /// Factory constructor to create ServiceInfo from Kubernetes API response
  factory ServiceInfo.fromK8sService(dynamic service) {
    // Extract service metadata
    final name = service.metadata?.name ?? 'Unknown';
    final namespace = service.metadata?.namespace ?? 'default';
    final type = service.spec?.type ?? 'Unknown';

    String? clusterIP;
    if (type == 'ClusterIP') {
      // Extract cluster IP
      clusterIP = service.spec?.clusterIP ?? 'None';
    }

    // Extract ports
    final ports = service.spec?.ports ?? [];
    
    // Calculate age
    String? age;
    if (service.metadata?.creationTimestamp != null) {
      try {
        final creationTimestamp = service.metadata!.creationTimestamp;
        final DateTime creationTime;
        
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
    
    return ServiceInfo(
      name: name,
      namespace: namespace,
      type: type,
      clusterIP: clusterIP,
      ports: ports,
      age: age,
    );
  }
}
