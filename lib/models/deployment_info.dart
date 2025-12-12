/// Model class representing a Kubernetes Deployment
class DeploymentInfo {
  final String name;
  final String namespace;
  final int replicas;
  final int readyReplicas;
  final int availableReplicas;
  final int updatedReplicas;
  final String? age;

  DeploymentInfo({
    required this.name,
    required this.namespace,
    required this.replicas,
    required this.readyReplicas,
    required this.availableReplicas,
    required this.updatedReplicas,
    this.age,
  });

  /// Factory constructor to create DeploymentInfo from Kubernetes API response
  factory DeploymentInfo.fromK8sDeployment(dynamic deployment) {
    // Extract deployment metadata
    final name = deployment.metadata?.name ?? 'Unknown';
    final namespace = deployment.metadata?.namespace ?? 'default';
    
    // Extract spec details
    final replicas = deployment.spec?.replicas ?? 0;
    
    // Extract status details
    final readyReplicas = deployment.status?.readyReplicas ?? 0;
    final availableReplicas = deployment.status?.availableReplicas ?? 0;
    final updatedReplicas = deployment.status?.updatedReplicas ?? 0;
    
    // Calculate age
    String? age;
    if (deployment.metadata?.creationTimestamp != null) {
      try {
        final creationTimestamp = deployment.metadata!.creationTimestamp;
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
    
    return DeploymentInfo(
      name: name,
      namespace: namespace,
      replicas: replicas,
      readyReplicas: readyReplicas,
      availableReplicas: availableReplicas,
      updatedReplicas: updatedReplicas,
      age: age,
    );
  }
}

