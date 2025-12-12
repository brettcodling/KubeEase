import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../services/kubernetes_service.dart';
import '../widgets/context_drawer.dart';
import '../widgets/namespace_drawer.dart';
import '../widgets/resource_menu.dart';
import '../widgets/resource_content.dart';
import '../widgets/ship_helm_icon.dart';
import '../exceptions/authentication_exception.dart';

/// Main screen widget that displays Kubernetes cluster information
class ClusterViewScreen extends StatefulWidget {
  const ClusterViewScreen({super.key});

  @override
  State<ClusterViewScreen> createState() => _ClusterViewScreenState();
}

/// State class for ClusterViewScreen
class _ClusterViewScreenState extends State<ClusterViewScreen> {
  // Context-related state
  List<String> _availableContexts = [];
  String _activeContext = '';

  // Kubernetes client and configuration
  Kubernetes? _kubernetesClient;
  Kubeconfig? _kubeconfig;

  // Namespace-related state
  List<String> _availableNamespaces = [];
  Set<String> _selectedNamespaces = {};
  bool _isLoadingNamespaces = false;
  StreamSubscription<List<String>>? _namespaceStreamSubscription;

  // Resource type selection state
  ResourceType _selectedResourceType = ResourceType.pods;

  // Error state
  AuthenticationException? _authError;

  @override
  void initState() {
    super.initState();
    // Initialize the app when the widget is first created
    _initializeApp();
  }

  @override
  void dispose() {
    // Cancel namespace stream subscription when widget is disposed
    _namespaceStreamSubscription?.cancel();
    super.dispose();
  }

  /// Orchestrates the initialization sequence for the application
  Future<void> _initializeApp() async {
    // Step 1: Load kubeconfig and initialize Kubernetes client
    final success = await _initialize();

    // Only continue if initialization was successful
    if (success) {
      // Step 2: Load available contexts from kubeconfig
      _loadContexts();
      // Step 3: Load namespaces from the current context
      _loadNamespaces();
    }
  }

  /// Reads the kubeconfig file and initializes the Kubernetes client
  /// Returns true if successful, false otherwise
  Future<bool> _initialize() async {
    try {
      final (client, config) = await KubernetesService.initialize();
      setState(() {
        _kubernetesClient = client;
        _kubeconfig = config;
        _authError = null; // Clear any previous errors
      });
      return true;
    } on AuthenticationException catch (e) {
      setState(() {
        _authError = e;
      });
      // Show error dialog
      if (mounted) {
        _showAuthenticationErrorDialog(e);
      }
      return false;
    } catch (e) {
      // Handle other errors
      if (mounted) {
        _showGenericErrorDialog(e.toString());
      }
      return false;
    }
  }

  /// Loads the list of available contexts from the kubeconfig file
  void _loadContexts() {
    if (_kubeconfig == null) return;

    final (contexts, activeContext) = KubernetesService.loadContexts(_kubeconfig!);
    setState(() {
      _availableContexts = contexts;
      _activeContext = activeContext;
    });
  }

  /// Watches the list of namespaces from the current Kubernetes context
  void _loadNamespaces() {
    if (_kubernetesClient == null) return;

    // Cancel any existing namespace subscription
    _namespaceStreamSubscription?.cancel();

    // Set loading state to show spinner in UI
    setState(() {
      _isLoadingNamespaces = true;
      _availableNamespaces = [];
    });

    // Subscribe to the namespace watch stream
    _namespaceStreamSubscription = KubernetesService.watchNamespaces(_kubernetesClient!).listen(
      (namespaces) {
        // Update the namespace list when new data arrives
        if (mounted) {
          setState(() {
            _availableNamespaces = namespaces;
            _isLoadingNamespaces = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching namespaces: $error');
        if (mounted) {
          setState(() {
            _isLoadingNamespaces = false;
          });
        }
      },
    );
  }

  /// Handles context selection from the drawer
  Future<void> _onContextSelected(String contextName) async {
    if (_kubeconfig == null) return;

    // Cancel existing namespace watcher before switching contexts
    _namespaceStreamSubscription?.cancel();

    // Set loading state immediately for instant UI feedback
    setState(() {
      _activeContext = contextName;
      _isLoadingNamespaces = true;
      // Clear selected namespaces when switching contexts
      _selectedNamespaces.clear();
    });

    try {
      // Switch to the new context
      final (client, config) = await KubernetesService.switchContext(contextName, _kubeconfig!);
      setState(() {
        _kubernetesClient = client;
        _kubeconfig = config;
        _authError = null; // Clear any previous errors
      });

      // Start watching namespaces for the new context
      _loadNamespaces();
    } on AuthenticationException catch (e) {
      setState(() {
        _authError = e;
        _isLoadingNamespaces = false;
      });
      // Show error dialog
      if (mounted) {
        _showAuthenticationErrorDialog(e);
      }
    } catch (e) {
      setState(() {
        _isLoadingNamespaces = false;
      });
      // Handle other errors
      if (mounted) {
        _showGenericErrorDialog(e.toString());
      }
    }
  }

  /// Handles namespace selection changes from the drawer
  void _onNamespaceSelectionChanged(Set<String> selectedNamespaces) {
    setState(() {
      _selectedNamespaces = selectedNamespaces;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Left drawer for context selection
      drawer: ContextDrawer(
        availableContexts: _availableContexts,
        activeContext: _activeContext,
        onContextSelected: _onContextSelected,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const ShipHelmIcon(size: 28),
        actions: [
          // Button to open namespace drawer (right side of AppBar)
          Builder(
            builder: (context) => IconButton(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show loading spinner or filter icon
                  if (_isLoadingNamespaces)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, // Thinner stroke for smaller size
                      ),
                    )
                  else
                    const Icon(Icons.filter_list),
                  const SizedBox(width: 4),
                  // Show loading text or selection count
                  Text(
                    _isLoadingNamespaces
                        ? 'Loading...'
                        : _selectedNamespaces.isEmpty
                            ? 'No Namespaces Selected'
                            : '${_selectedNamespaces.length} Namespaces Selected',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              // Disable button while loading
              onPressed: _isLoadingNamespaces
                  ? null
                  : () {
                      Scaffold.of(context).openEndDrawer(); // Open right drawer
                    },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Right drawer for namespace selection
      endDrawer: NamespaceDrawer(
        availableNamespaces: _availableNamespaces,
        selectedNamespaces: _selectedNamespaces,
        isLoadingNamespaces: _isLoadingNamespaces,
        onSelectionChanged: _onNamespaceSelectionChanged,
      ),
      // Main body content
      body: _selectedNamespaces.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Namespaces Selected',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please select one or more namespaces from the filter menu',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            )
          : _kubernetesClient == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Row(
                  children: [
                    // Left menu bar for resource types
                    ResourceMenu(
                      selectedResourceType: _selectedResourceType,
                      onResourceTypeSelected: (ResourceType type) {
                        setState(() {
                          _selectedResourceType = type;
                        });
                      },
                    ),
                    // Main content area
                    Expanded(
                      child: ResourceContent(
                        resourceType: _selectedResourceType,
                        selectedNamespaces: _selectedNamespaces,
                        kubernetesClient: _kubernetesClient!,
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Shows a detailed authentication error dialog with platform-specific instructions
  void _showAuthenticationErrorDialog(AuthenticationException error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Prevent dismissing with back button
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 28),
                const SizedBox(width: 12),
                const Text('Authentication Failed'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.getShortMessage(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SelectableText(
                      error.getUserFriendlyMessage(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Retry initialization
                  await _initializeApp();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              if (_availableContexts.length > 1)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Open context drawer to allow switching
                    Scaffold.of(context).openDrawer();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Switch Context'),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Shows a generic error dialog for non-authentication errors
  void _showGenericErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 12),
              const Text('Error'),
            ],
          ),
          content: SelectableText(errorMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
