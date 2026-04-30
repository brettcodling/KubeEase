import 'package:flutter/foundation.dart';
import 'package:k8s/k8s.dart';
import '../connection_error_manager.dart';

/// Cloud-provider identity bound to a Kubernetes ServiceAccount via
/// well-known annotations (GKE Workload Identity, EKS IRSA, AKS Workload
/// Identity).
class CloudIdentity {
  const CloudIdentity({required this.provider, required this.value});

  final String provider;
  final String value;
}

/// Service for looking up cloud-provider identities bound to a Kubernetes
/// ServiceAccount.
class ServiceAccountService {
  /// Annotation keys, in priority order, that map a Kubernetes ServiceAccount
  /// to a cloud-provider identity. The value displayed is the annotation's
  /// raw value (an email on GCP, an ARN on AWS, a client-id on Azure).
  static const List<({String key, String provider})> _providerAnnotations = [
    (key: 'iam.gke.io/gcp-service-account', provider: 'GCP'),
    (key: 'eks.amazonaws.com/role-arn', provider: 'AWS'),
    (key: 'azure.workload.identity/client-id', provider: 'Azure'),
  ];

  /// Fetches the named ServiceAccount and returns the first cloud-provider
  /// identity annotation found, or `null` if the SA has none / the lookup
  /// fails.
  static Future<CloudIdentity?> resolveCloudIdentity(
    Kubernetes kubernetesClient,
    String namespace,
    String serviceAccountName,
  ) async {
    try {
      final coreV1Api = kubernetesClient.client.getCoreV1Api();
      final response = await coreV1Api.readNamespacedServiceAccount(
        name: serviceAccountName,
        namespace: namespace,
      );
      final annotations = response.data?.metadata?.annotations ?? const {};
      for (final entry in _providerAnnotations) {
        final value = annotations[entry.key];
        if (value != null && value.isNotEmpty) {
          return CloudIdentity(provider: entry.provider, value: value);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error resolving cloud identity for $serviceAccountName in $namespace: $e');
      // Surface connection errors to the manager so the global reconnection
      // flow kicks in; otherwise swallow so the detail screen still renders.
      ConnectionErrorManager().checkAndHandleError(e);
      return null;
    }
  }
}
