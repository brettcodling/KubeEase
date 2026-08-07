import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import 'resource_menu.dart';
import 'pods_list.dart';
import 'deployments_list.dart';
import 'cron_jobs_list.dart';
import 'secrets_list.dart';
import 'services_list.dart';
import 'custom_resources_list.dart';
import '../models/pod_info.dart';
import '../models/deployment_info.dart';
import '../models/cron_job_info.dart';
import '../models/secret_info.dart';
import '../models/service_info.dart';
import '../models/custom_resource_info.dart';
import '../services/pods/pod_service.dart';
import '../services/deployments/deployment_service.dart';
import '../services/cron_jobs/cron_job_service.dart';
import '../services/secrets/secret_service.dart';
import '../services/services/service_service.dart';
import '../services/custom_resources/custom_resource_service.dart';

/// Main content area widget that displays the selected resource type
class ResourceContent extends StatefulWidget {
  const ResourceContent({
    super.key,
    required this.resourceType,
    required this.selectedNamespaces,
    required this.kubernetesClient,
    this.selectedCustomResource,
  });

  final ResourceType resourceType;
  final Set<String> selectedNamespaces;
  final Kubernetes kubernetesClient;
  final CustomResourceDefinitionInfo? selectedCustomResource;

  @override
  State<ResourceContent> createState() => _ResourceContentState();
}

/// Enum for pod sort fields
enum PodSortField {
  name,
  namespace,
  status,
  age,
  restarts,
}

/// Enum for cron job sort fields
enum CronJobSortField {
  name,
  namespace,
  schedule,
  suspended,
  activeJobs,
  age,
}

/// Enum for deployment sort fields
enum DeploymentSortField {
  name,
  namespace,
  replicas,
  ready,
  age,
}

/// Enum for secret sort fields
enum SecretSortField {
  name,
  namespace,
  type,
  dataCount,
  age,
}

/// Enum for service sort fields
enum ServiceSortField {
  name,
  namespace,
  age,
}

/// Enum for custom resource sort fields
enum CustomResourceSortField {
  name,
  namespace,
  age,
}

/// Enum for sort direction
enum SortDirection {
  ascending,
  descending,
}

class _ResourceContentState extends State<ResourceContent> {
  // Pods state
  List<PodInfo> _pods = [];
  StreamSubscription<List<PodInfo>>? _podStreamSubscription;
  PodSortField _podSortField = PodSortField.name;

  // Deployments state
  List<DeploymentInfo> _deployments = [];
  StreamSubscription<List<DeploymentInfo>>? _deploymentStreamSubscription;
  DeploymentSortField _deploymentSortField = DeploymentSortField.name;

  // CronJobs state
  List<CronJobInfo> _cronJobs = [];
  StreamSubscription<List<CronJobInfo>>? _cronJobStreamSubscription;
  CronJobSortField _cronJobSortField = CronJobSortField.name;

  // Secrets state
  List<SecretInfo> _secrets = [];
  StreamSubscription<List<SecretInfo>>? _secretStreamSubscription;
  SecretSortField _secretSortField = SecretSortField.name;

  // Services state
  List<ServiceInfo> _services = [];
  StreamSubscription<List<ServiceInfo>>? _serviceStreamSubscription;
  ServiceSortField _serviceSortField = ServiceSortField.name;

  // Custom Resources state
  List<CustomResourceInfo> _customResources = [];
  StreamSubscription<List<CustomResourceInfo>>? _customResourceStreamSubscription;
  CustomResourceSortField _customResourceSortField = CustomResourceSortField.name;

  // Common state
  bool _isLoading = false;
  SortDirection _sortDirection = SortDirection.ascending;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startWatchingResources();
  }

  @override
  void didUpdateWidget(ResourceContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final resourceChanged = oldWidget.resourceType != widget.resourceType ||
        oldWidget.selectedNamespaces != widget.selectedNamespaces ||
        oldWidget.selectedCustomResource != widget.selectedCustomResource;
    final clientChanged = oldWidget.kubernetesClient != widget.kubernetesClient;

    if (resourceChanged || clientChanged) {
      _cancelAllSubscriptions();
      if (resourceChanged) {
        // Real context/namespace/type switch — clear search and list data.
        _searchController.clear();
        _searchQuery = '';
        _startWatchingResources(clearData: true);
      } else {
        // Client-only refresh (e.g. token rotation) — preserve existing data
        // and filters so the user's view is not disrupted.
        _startWatchingResources(clearData: false);
      }
    }
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions when widget is disposed
    _cancelAllSubscriptions();
    // Dispose search controller
    _searchController.dispose();
    super.dispose();
  }

  /// Cancels all active stream subscriptions
  void _cancelAllSubscriptions() {
    _podStreamSubscription?.cancel();
    _podStreamSubscription = null;
    _deploymentStreamSubscription?.cancel();
    _deploymentStreamSubscription = null;
    _cronJobStreamSubscription?.cancel();
    _cronJobStreamSubscription = null;
    _secretStreamSubscription?.cancel();
    _secretStreamSubscription = null;
    _serviceStreamSubscription?.cancel();
    _serviceStreamSubscription = null;
    _customResourceStreamSubscription?.cancel();
    _customResourceStreamSubscription = null;
  }

  /// Pauses watching resources (called when navigating to detail screen)
  void _pauseWatching() {
    _cancelAllSubscriptions();
  }

  /// Resumes watching resources (called when returning from detail screen)
  void _resumeWatching() {
    _startWatchingResources();
  }

  /// Starts watching resources based on the selected resource type.
  /// [clearData] — when true, clears existing list data before subscribing
  /// (used on resource/namespace switches). When false (token refresh), the
  /// existing data stays visible until the new stream delivers results.
  void _startWatchingResources({bool clearData = true}) {
    switch (widget.resourceType) {
      case ResourceType.pods:
        _watchPods(clearData: clearData);
        break;
      case ResourceType.deployments:
        _watchDeployments(clearData: clearData);
        break;
      case ResourceType.cronJobs:
        _watchCronJobs(clearData: clearData);
        break;
      case ResourceType.secrets:
        _watchSecrets(clearData: clearData);
        break;
      case ResourceType.services:
        _watchServices(clearData: clearData);
        break;
      case ResourceType.customResource:
        _watchCustomResources(clearData: clearData);
        break;
    }
  }

  /// Watches pods from Kubernetes using a stream
  void _watchPods({bool clearData = true}) {
    // Cancel any existing subscription
    _podStreamSubscription?.cancel();

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _pods = [];
      });
    }

    // Subscribe to the pod watch stream
    _podStreamSubscription = PodService.watchPods(
      widget.kubernetesClient,
      widget.selectedNamespaces,
    ).listen(
      (pods) {
        // Update the pod list when new data arrives
        if (mounted) {
          setState(() {
            _pods = pods;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching pods: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Watches deployments from Kubernetes using a stream
  void _watchDeployments({bool clearData = true}) {
    // Cancel any existing subscription
    _deploymentStreamSubscription?.cancel();

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _deployments = [];
      });
    }

    // Subscribe to the deployment watch stream
    _deploymentStreamSubscription = DeploymentService.watchDeployments(
      widget.kubernetesClient,
      widget.selectedNamespaces,
    ).listen(
      (deployments) {
        // Update the deployment list when new data arrives
        if (mounted) {
          setState(() {
            _deployments = deployments;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching deployments: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Watches cron jobs from Kubernetes using a stream
  void _watchCronJobs({bool clearData = true}) {
    // Cancel any existing subscription
    _cronJobStreamSubscription?.cancel();

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _cronJobs = [];
      });
    }

    // Subscribe to the cron job watch stream
    _cronJobStreamSubscription = CronJobService.watchCronJobs(
      widget.kubernetesClient,
      widget.selectedNamespaces,
    ).listen(
      (cronJobs) {
        // Update the cron job list when new data arrives
        if (mounted) {
          setState(() {
            _cronJobs = cronJobs;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching cron jobs: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Watches secrets from Kubernetes using a stream
  void _watchSecrets({bool clearData = true}) {
    // Cancel any existing subscription
    _secretStreamSubscription?.cancel();

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _secrets = [];
      });
    }

    // Subscribe to the secret watch stream
    _secretStreamSubscription = SecretService.watchSecrets(
      widget.kubernetesClient,
      widget.selectedNamespaces,
    ).listen(
      (secrets) {
        // Update the secret list when new data arrives
        if (mounted) {
          setState(() {
            _secrets = secrets;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching secrets: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Watches services from Kubernetes using a stream
  void _watchServices({bool clearData = true}) {
    // Cancel any existing subscription
    _serviceStreamSubscription?.cancel();

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _services = [];
      });
    }

    // Subscribe to the service watch stream
    _serviceStreamSubscription = ServiceService.watchServices(
      widget.kubernetesClient,
      widget.selectedNamespaces,
    ).listen(
      (services) {
        // Update the service list when new data arrives
        if (mounted) {
          setState(() {
            _services = services;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching services: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Watches custom resources from Kubernetes using a stream
  void _watchCustomResources({bool clearData = true}) {
    // Cancel any existing subscription
    _customResourceStreamSubscription?.cancel();

    // Check if a custom resource is selected
    if (widget.selectedCustomResource == null) {
      if (mounted) {
        setState(() {
          if (clearData) _customResources = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        if (clearData) _customResources = [];
      });
    }

    // Subscribe to the custom resource watch stream
    _customResourceStreamSubscription = CustomResourceService.watchCustomResources(
      widget.kubernetesClient,
      widget.selectedCustomResource!,
      widget.selectedNamespaces,
    ).listen(
      (resources) {
        // Update the custom resource list when new data arrives
        if (mounted) {
          setState(() {
            _customResources = resources;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error watching custom resources: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Filters and sorts the pod list based on search query, sort field and direction
  List<PodInfo> _getSortedPods() {
    // First filter by search query
    var filteredPods = _pods.where((pod) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return pod.name.toLowerCase().contains(query) ||
          pod.namespace.toLowerCase().contains(query) ||
          pod.status.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredPods.sort((a, b) {
      int comparison;

      switch (_podSortField) {
        case PodSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case PodSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case PodSortField.status:
          comparison = a.status.compareTo(b.status);
          break;
        case PodSortField.age:
          // Sort by age (newer first when ascending)
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
        case PodSortField.restarts:
          comparison = a.restartCount.compareTo(b.restartCount);
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredPods;
  }

  /// Filters and sorts the deployment list based on search query, sort field and direction
  List<DeploymentInfo> _getSortedDeployments() {
    // First filter by search query
    var filteredDeployments = _deployments.where((deployment) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return deployment.name.toLowerCase().contains(query) ||
          deployment.namespace.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredDeployments.sort((a, b) {
      int comparison;

      switch (_deploymentSortField) {
        case DeploymentSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case DeploymentSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case DeploymentSortField.replicas:
          comparison = a.replicas.compareTo(b.replicas);
          break;
        case DeploymentSortField.ready:
          comparison = a.readyReplicas.compareTo(b.readyReplicas);
          break;
        case DeploymentSortField.age:
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredDeployments;
  }

  /// Filters and sorts the cron job list based on search query, sort field and direction
  List<CronJobInfo> _getSortedCronJobs() {
    // First filter by search query
    var filteredCronJobs = _cronJobs.where((cronJob) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return cronJob.name.toLowerCase().contains(query) ||
          cronJob.namespace.toLowerCase().contains(query) ||
          cronJob.schedule.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredCronJobs.sort((a, b) {
      int comparison;

      switch (_cronJobSortField) {
        case CronJobSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case CronJobSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case CronJobSortField.schedule:
          comparison = a.schedule.compareTo(b.schedule);
          break;
        case CronJobSortField.suspended:
          comparison = a.suspended.toString().compareTo(b.suspended.toString());
          break;
        case CronJobSortField.activeJobs:
          comparison = (a.activeJobs ?? 0).compareTo(b.activeJobs ?? 0);
          break;
        case CronJobSortField.age:
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredCronJobs;
  }

  /// Filters and sorts the secret list based on search query, sort field and direction
  List<SecretInfo> _getSortedSecrets() {
    // First filter by search query
    var filteredSecrets = _secrets.where((secret) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return secret.name.toLowerCase().contains(query) ||
          secret.namespace.toLowerCase().contains(query) ||
          secret.type.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredSecrets.sort((a, b) {
      int comparison;

      switch (_secretSortField) {
        case SecretSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SecretSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case SecretSortField.type:
          comparison = a.type.compareTo(b.type);
          break;
        case SecretSortField.dataCount:
          comparison = a.dataCount.compareTo(b.dataCount);
          break;
        case SecretSortField.age:
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredSecrets;
  }

  /// Filters and sorts the service list based on search query, sort field and direction
  List<ServiceInfo> _getSortedServices() {
    // First filter by search query
    var filteredServices = _services.where((service) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return service.name.toLowerCase().contains(query) ||
          service.namespace.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredServices.sort((a, b) {
      int comparison;

      switch (_serviceSortField) {
        case ServiceSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case ServiceSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case ServiceSortField.age:
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredServices;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with resource type title and sort controls
          LayoutBuilder(
            builder: (context, constraints) {
              // Hide sort controls when width is less than 400px
              final showSortControls = constraints.maxWidth >= 400;

              return Row(
                children: [
                  Icon(
                    _getIconForResourceType(widget.resourceType),
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getTitleForResourceType(widget.resourceType),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showSortControls) ...[
                    const SizedBox(width: 8),
                    // Sort controls for all resource types
                    _buildSortControls(),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Search box
          _buildSearchBox(),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 24),

          // Content based on resource type
          Expanded(
            child: _buildResourceContent(),
          ),
        ],
      ),
    );
  }

  /// Builds the content based on the selected resource type
  Widget _buildResourceContent() {
    switch (widget.resourceType) {
      case ResourceType.pods:
        // Use sorted pods
        final sortedPods = _getSortedPods();
        return PodsList(
          pods: sortedPods,
          isLoading: _isLoading,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
      case ResourceType.deployments:
        // Use sorted deployments
        final sortedDeployments = _getSortedDeployments();
        return DeploymentsList(
          deployments: sortedDeployments,
          isLoading: _isLoading,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
      case ResourceType.cronJobs:
        // Use sorted cron jobs
        final sortedCronJobs = _getSortedCronJobs();
        return CronJobsList(
          cronJobs: sortedCronJobs,
          isLoading: _isLoading,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
      case ResourceType.secrets:
        // Use sorted secrets
        final sortedSecrets = _getSortedSecrets();
        return SecretsList(
          secrets: sortedSecrets,
          isLoading: _isLoading,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
      case ResourceType.services:
        // Use sorted services
        final sortedServices = _getSortedServices();
        return ServicesList(
          services: sortedServices,
          isLoading: _isLoading,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
      case ResourceType.customResource:
        // Use filtered and sorted custom resources
        final sortedResources = _getSortedCustomResources();
        return CustomResourcesList(
          resources: sortedResources,
          isLoading: _isLoading,
          crd: widget.selectedCustomResource,
          kubernetesClient: widget.kubernetesClient,
          onPauseWatching: _pauseWatching,
          onResumeWatching: _resumeWatching,
        );
    }
  }

  /// Filters and sorts the custom resource list based on search query, sort field and direction
  List<CustomResourceInfo> _getSortedCustomResources() {
    // First filter by search query
    var filteredResources = _customResources.where((resource) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return resource.name.toLowerCase().contains(query) ||
          resource.namespace.toLowerCase().contains(query) ||
          resource.kind.toLowerCase().contains(query);
    }).toList();

    // Then sort
    filteredResources.sort((a, b) {
      int comparison;

      switch (_customResourceSortField) {
        case CustomResourceSortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case CustomResourceSortField.namespace:
          comparison = a.namespace.compareTo(b.namespace);
          break;
        case CustomResourceSortField.age:
          comparison = (a.age ?? '').compareTo(b.age ?? '');
          break;
      }

      // Reverse if descending
      return _sortDirection == SortDirection.ascending ? comparison : -comparison;
    });

    return filteredResources;
  }

  /// Builds the search box widget
  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name, namespace, or ${_getSearchHintSuffix()}...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  /// Gets the search hint suffix based on resource type
  String _getSearchHintSuffix() {
    switch (widget.resourceType) {
      case ResourceType.pods:
        return 'status';
      case ResourceType.deployments:
        return 'replicas';
      case ResourceType.cronJobs:
        return 'schedule';
      case ResourceType.secrets:
        return 'type';
      case ResourceType.services:
        return 'name';
      case ResourceType.customResource:
        return 'kind';
    }
  }

  /// Builds the sort controls widget
  Widget _buildSortControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort label
          Text(
            'Sort by:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(width: 8),
          // Sort field dropdown - different for each resource type
          _buildSortFieldDropdown(),
          const SizedBox(width: 4),
          // Sort direction toggle button
          IconButton(
            icon: Icon(
              _sortDirection == SortDirection.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 20,
            ),
            tooltip: _sortDirection == SortDirection.ascending
                ? 'Ascending'
                : 'Descending',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _sortDirection = _sortDirection == SortDirection.ascending
                    ? SortDirection.descending
                    : SortDirection.ascending;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Builds the sort field dropdown based on resource type
  Widget _buildSortFieldDropdown() {
    switch (widget.resourceType) {
      case ResourceType.pods:
        return DropdownButton<PodSortField>(
          value: _podSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: PodSortField.name, child: Text('Name')),
            DropdownMenuItem(value: PodSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: PodSortField.status, child: Text('Status')),
            DropdownMenuItem(value: PodSortField.age, child: Text('Age')),
            DropdownMenuItem(value: PodSortField.restarts, child: Text('Restarts')),
          ],
          onChanged: (PodSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _podSortField = newValue;
              });
            }
          },
        );
      case ResourceType.deployments:
        return DropdownButton<DeploymentSortField>(
          value: _deploymentSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: DeploymentSortField.name, child: Text('Name')),
            DropdownMenuItem(value: DeploymentSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: DeploymentSortField.replicas, child: Text('Replicas')),
            DropdownMenuItem(value: DeploymentSortField.ready, child: Text('Ready')),
            DropdownMenuItem(value: DeploymentSortField.age, child: Text('Age')),
          ],
          onChanged: (DeploymentSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _deploymentSortField = newValue;
              });
            }
          },
        );
      case ResourceType.cronJobs:
        return DropdownButton<CronJobSortField>(
          value: _cronJobSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: CronJobSortField.name, child: Text('Name')),
            DropdownMenuItem(value: CronJobSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: CronJobSortField.schedule, child: Text('Schedule')),
            DropdownMenuItem(value: CronJobSortField.suspended, child: Text('Status')),
            DropdownMenuItem(value: CronJobSortField.activeJobs, child: Text('Active Jobs')),
            DropdownMenuItem(value: CronJobSortField.age, child: Text('Age')),
          ],
          onChanged: (CronJobSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _cronJobSortField = newValue;
              });
            }
          },
        );
      case ResourceType.secrets:
        return DropdownButton<SecretSortField>(
          value: _secretSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: SecretSortField.name, child: Text('Name')),
            DropdownMenuItem(value: SecretSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: SecretSortField.type, child: Text('Type')),
            DropdownMenuItem(value: SecretSortField.dataCount, child: Text('Data Keys')),
            DropdownMenuItem(value: SecretSortField.age, child: Text('Age')),
          ],
          onChanged: (SecretSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _secretSortField = newValue;
              });
            }
          },
        );
      case ResourceType.services:
        return DropdownButton<ServiceSortField>(
          value: _serviceSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: ServiceSortField.name, child: Text('Name')),
            DropdownMenuItem(value: ServiceSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: ServiceSortField.age, child: Text('Age')),
          ],
          onChanged: (ServiceSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _serviceSortField = newValue;
              });
            }
          },
        );
      case ResourceType.customResource:
        return DropdownButton<CustomResourceSortField>(
          value: _customResourceSortField,
          underline: Container(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(8),
          items: const [
            DropdownMenuItem(value: CustomResourceSortField.name, child: Text('Name')),
            DropdownMenuItem(value: CustomResourceSortField.namespace, child: Text('Namespace')),
            DropdownMenuItem(value: CustomResourceSortField.age, child: Text('Age')),
          ],
          onChanged: (CustomResourceSortField? newValue) {
            if (newValue != null) {
              setState(() {
                _customResourceSortField = newValue;
              });
            }
          },
        );
    }
  }

  /// Returns the appropriate icon for the resource type
  IconData _getIconForResourceType(ResourceType type) {
    switch (type) {
      case ResourceType.pods:
        return Icons.widgets;
      case ResourceType.deployments:
        return Icons.apps;
      case ResourceType.cronJobs:
        return Icons.schedule;
      case ResourceType.secrets:
        return Icons.lock;
      case ResourceType.services:
        return Icons.network_check;
      case ResourceType.customResource:
        return Icons.extension;
    }
  }

  /// Returns the display title for the resource type
  String _getTitleForResourceType(ResourceType type) {
    switch (type) {
      case ResourceType.pods:
        return 'Pods';
      case ResourceType.deployments:
        return 'Deployments';
      case ResourceType.cronJobs:
        return 'Cron Jobs';
      case ResourceType.secrets:
        return 'Secrets';
      case ResourceType.services:
        return 'Services';
      case ResourceType.customResource:
        return widget.selectedCustomResource?.kind ?? 'Custom Resource';
    }
  }
}

