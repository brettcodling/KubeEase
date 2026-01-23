/// Model class representing a Kubernetes Custom Resource
class CustomResourceInfo {
  final String name;
  final String namespace;
  final String kind;
  final String apiVersion;
  final String? age;
  final Map<String, dynamic>? spec;
  final Map<String, dynamic>? status;

  CustomResourceInfo({
    required this.name,
    required this.namespace,
    required this.kind,
    required this.apiVersion,
    this.age,
    this.spec,
    this.status,
  });

  /// Creates a CustomResourceInfo from a Kubernetes custom resource object
  factory CustomResourceInfo.fromK8sResource(dynamic resource) {
    final metadata = resource['metadata'] as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ?? 'Unknown';
    final namespace = metadata?['namespace'] as String? ?? 'default';
    final kind = resource['kind'] as String? ?? 'Unknown';
    final apiVersion = resource['apiVersion'] as String? ?? 'Unknown';
    
    // Calculate age from creation timestamp
    String? age;
    final creationTimestamp = metadata?['creationTimestamp'] as String?;
    if (creationTimestamp != null) {
      try {
        final createdAt = DateTime.parse(creationTimestamp);
        final now = DateTime.now();
        final difference = now.difference(createdAt);
        
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

    final spec = resource['spec'] as Map<String, dynamic>?;
    final status = resource['status'] as Map<String, dynamic>?;

    return CustomResourceInfo(
      name: name,
      namespace: namespace,
      kind: kind,
      apiVersion: apiVersion,
      age: age,
      spec: spec,
      status: status,
    );
  }
}

/// Model class representing a Custom Resource Definition (CRD)
class CustomResourceDefinitionInfo {
  final String name;
  final String kind;
  final String group;
  final String version;
  final String scope;
  final String plural;
  final String singular;

  CustomResourceDefinitionInfo({
    required this.name,
    required this.kind,
    required this.group,
    required this.version,
    required this.scope,
    required this.plural,
    required this.singular,
  });

  /// Creates a CustomResourceDefinitionInfo from a Kubernetes CRD object
  factory CustomResourceDefinitionInfo.fromK8sCRD(dynamic crd) {
    final metadata = crd['metadata'] as Map<String, dynamic>?;
    final spec = crd['spec'] as Map<String, dynamic>?;
    final names = spec?['names'] as Map<String, dynamic>?;
    
    // Get the preferred version or the first available version
    String version = '';
    final versions = spec?['versions'] as List<dynamic>?;
    if (versions != null && versions.isNotEmpty) {
      // Find the storage version or the first version
      final storageVersion = versions.firstWhere(
        (v) => v['storage'] == true,
        orElse: () => versions.first,
      );
      version = storageVersion['name'] as String? ?? '';
    }

    return CustomResourceDefinitionInfo(
      name: metadata?['name'] as String? ?? 'Unknown',
      kind: names?['kind'] as String? ?? 'Unknown',
      group: spec?['group'] as String? ?? '',
      version: version,
      scope: spec?['scope'] as String? ?? 'Namespaced',
      plural: names?['plural'] as String? ?? '',
      singular: names?['singular'] as String? ?? '',
    );
  }

  /// Returns the full API version (group/version)
  String get apiVersion => group.isEmpty ? version : '$group/$version';
}

