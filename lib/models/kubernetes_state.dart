import 'package:k8s/k8s.dart';

/// Model class that holds all Kubernetes-related state
class KubernetesState {
  // Context-related state
  List<String> availableContexts; // List of all available Kubernetes contexts
  String activeContext; // Currently selected context
  
  // Kubernetes client and configuration
  Kubernetes kubernetesClient; // Client for interacting with Kubernetes API
  Kubeconfig? kubeconfig; // Parsed kubeconfig file
  
  // Namespace-related state
  List<String> availableNamespaces; // List of all namespaces in the current context
  Set<String> selectedNamespaces; // Set of namespaces selected by the user
  bool isLoadingNamespaces; // Flag to track namespace loading state
  String namespaceSearchQuery; // Search query for filtering namespaces

  KubernetesState({
    this.availableContexts = const [],
    this.activeContext = '',
    Kubernetes? kubernetesClient,
    this.kubeconfig,
    this.availableNamespaces = const [],
    Set<String>? selectedNamespaces,
    this.isLoadingNamespaces = false,
    this.namespaceSearchQuery = '',
  })  : kubernetesClient = kubernetesClient ?? Kubernetes(),
        selectedNamespaces = selectedNamespaces ?? {};

  /// Creates a copy of this state with the given fields replaced
  KubernetesState copyWith({
    List<String>? availableContexts,
    String? activeContext,
    Kubernetes? kubernetesClient,
    Kubeconfig? kubeconfig,
    List<String>? availableNamespaces,
    Set<String>? selectedNamespaces,
    bool? isLoadingNamespaces,
    String? namespaceSearchQuery,
  }) {
    return KubernetesState(
      availableContexts: availableContexts ?? this.availableContexts,
      activeContext: activeContext ?? this.activeContext,
      kubernetesClient: kubernetesClient ?? this.kubernetesClient,
      kubeconfig: kubeconfig ?? this.kubeconfig,
      availableNamespaces: availableNamespaces ?? this.availableNamespaces,
      selectedNamespaces: selectedNamespaces ?? this.selectedNamespaces,
      isLoadingNamespaces: isLoadingNamespaces ?? this.isLoadingNamespaces,
      namespaceSearchQuery: namespaceSearchQuery ?? this.namespaceSearchQuery,
    );
  }
}

