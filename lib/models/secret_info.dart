/// Model class representing a Kubernetes Secret
class SecretInfo {
  final String name;
  final String namespace;
  final String type;
  final int dataCount;
  final String? age;

  SecretInfo({
    required this.name,
    required this.namespace,
    required this.type,
    required this.dataCount,
    this.age,
  });

  /// Factory constructor to create SecretInfo from Kubernetes API response
  factory SecretInfo.fromK8sSecret(dynamic secret) {
    // Extract secret metadata
    final name = secret.metadata?.name ?? 'Unknown';
    final namespace = secret.metadata?.namespace ?? 'default';
    
    // Extract type
    final type = secret.type ?? 'Opaque';
    
    // Count data entries
    final dataCount = secret.data?.length ?? 0;
    
    // Calculate age
    String? age;
    if (secret.metadata?.creationTimestamp != null) {
      try {
        final creationTimestamp = secret.metadata!.creationTimestamp;
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
    
    return SecretInfo(
      name: name,
      namespace: namespace,
      type: type,
      dataCount: dataCount,
      age: age,
    );
  }
}

