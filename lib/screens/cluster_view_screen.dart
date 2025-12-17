import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../services/kubernetes_service.dart';
import '../services/port_forward_manager.dart';
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

  // Remember selected namespaces per context (not persisted between app launches)
  final Map<String, Set<String>> _contextNamespaceMemory = {};

  // Kubeconfig file watcher
  StreamSubscription<String>? _kubeconfigWatcherSubscription;

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
    // Cancel all stream subscriptions when widget is disposed
    _namespaceStreamSubscription?.cancel();
    _kubeconfigWatcherSubscription?.cancel();
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
      // Step 4: Start watching for external kubeconfig changes
      _startWatchingKubeconfig();
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

          // Restore remembered namespaces for this context if they exist
          _restoreRememberedNamespaces();
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

  /// Restores previously selected namespaces for the current context
  void _restoreRememberedNamespaces() {
    if (_activeContext.isEmpty) return;

    // Check if we have remembered namespaces for this context
    final rememberedNamespaces = _contextNamespaceMemory[_activeContext];
    if (rememberedNamespaces != null && rememberedNamespaces.isNotEmpty) {
      // Only restore namespaces that still exist in the available namespaces
      final validNamespaces = rememberedNamespaces
          .where((ns) => _availableNamespaces.contains(ns))
          .toSet();

      if (validNamespaces.isNotEmpty && validNamespaces != _selectedNamespaces) {
        setState(() {
          _selectedNamespaces = validNamespaces;
        });
        debugPrint('Restored ${validNamespaces.length} remembered namespaces for context: $_activeContext');
      }
    }
  }

  /// Handles context selection from the drawer
  Future<void> _onContextSelected(String contextName) async {
    if (_kubeconfig == null) return;

    // Save current context's selected namespaces before switching
    if (_activeContext.isNotEmpty && _selectedNamespaces.isNotEmpty) {
      _contextNamespaceMemory[_activeContext] = Set.from(_selectedNamespaces);
    }

    // Cancel existing namespace watcher before switching contexts
    _namespaceStreamSubscription?.cancel();

    // Set loading state immediately for instant UI feedback
    setState(() {
      _activeContext = contextName;
      _isLoadingNamespaces = true;
      // Clear selected namespaces when switching contexts (will be restored by _loadNamespaces if remembered)
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

  /// Starts watching the kubeconfig file for external changes
  void _startWatchingKubeconfig() {
    // Cancel any existing watcher
    _kubeconfigWatcherSubscription?.cancel();

    // Subscribe to kubeconfig changes
    _kubeconfigWatcherSubscription = KubernetesService.watchKubeconfigChanges().listen(
      (newContext) async {
        debugPrint('External kubeconfig change detected: context changed to $newContext');

        // Only process if the context is different from our current context
        if (newContext != _activeContext) {
          await _handleExternalContextChange(newContext);
        }
      },
      onError: (error) {
        debugPrint('Error watching kubeconfig: $error');
      },
    );
  }

  /// Handles external context changes (from kubectl or other tools)
  Future<void> _handleExternalContextChange(String newContext) async {
    debugPrint('Handling external context change to: $newContext');

    // Save current context's selected namespaces before switching
    if (_activeContext.isNotEmpty && _selectedNamespaces.isNotEmpty) {
      _contextNamespaceMemory[_activeContext] = Set.from(_selectedNamespaces);
    }

    // Navigate back to home screen if we're on a detail screen
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Cancel all existing watchers
    _namespaceStreamSubscription?.cancel();

    // Clear selected namespaces (will be restored by _loadNamespaces if remembered)
    setState(() {
      _activeContext = newContext;
      _selectedNamespaces.clear();
      _isLoadingNamespaces = true;
    });

    try {
      // Reinitialize the Kubernetes client with the new context
      final (client, config) = await KubernetesService.initialize();

      if (mounted) {
        setState(() {
          _kubernetesClient = client;
          _kubeconfig = config;
          _authError = null;
        });

        // Reload contexts to update the UI
        _loadContexts();

        // Start watching namespaces for the new context
        _loadNamespaces();
      }
    } on AuthenticationException catch (e) {
      if (mounted) {
        setState(() {
          _authError = e;
          _isLoadingNamespaces = false;
        });
        _showAuthenticationErrorDialog(e);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNamespaces = false;
        });
        _showGenericErrorDialog(e.toString());
      }
    }
  }

  /// Handles namespace selection changes from the drawer
  void _onNamespaceSelectionChanged(Set<String> selectedNamespaces) {
    setState(() {
      _selectedNamespaces = selectedNamespaces;
    });

    // Remember the selected namespaces for this context
    if (_activeContext.isNotEmpty) {
      _contextNamespaceMemory[_activeContext] = Set.from(selectedNamespaces);
    }
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
          // Port forward notification icon
          ListenableBuilder(
            listenable: PortForwardManager(),
            builder: (context, _) {
              final sessions = PortForwardManager().sessions;
              if (sessions.isEmpty) {
                return const SizedBox.shrink();
              }
              return Row(
                children: [
                  PopupMenuButton<String>(
                    icon: Badge(
                      label: Text('${sessions.length}'),
                      child: const Icon(Icons.forward),
                    ),
                    tooltip: 'Port Forwards',
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(
                            'Active Port Forwards',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const PopupMenuDivider(),
                        ...sessions.map((session) {
                          return PopupMenuItem<String>(
                            value: session.id,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.displayName,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Running for ${_formatDuration(DateTime.now().difference(session.startTime))}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ],
                            ),
                          );
                        }),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'stop_all',
                          child: Row(
                            children: [
                              Icon(Icons.clear_all, size: 18, color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                'Stop All',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                    onSelected: (value) {
                      if (value == 'stop_all') {
                        PortForwardManager().stopAll();
                      } else {
                        PortForwardManager().stopPortForward(value);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
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

  /// Formats a duration into a human-readable string
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
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
