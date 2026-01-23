import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../models/custom_resource_info.dart';
import '../services/custom_resources/custom_resource_service.dart';

/// Enum representing the different resource types available
enum ResourceType {
  pods,
  deployments,
  cronJobs,
  secrets,
  customResource,
}

/// Left sidebar menu widget for selecting Kubernetes resource types
class ResourceMenu extends StatefulWidget {
  const ResourceMenu({
    super.key,
    required this.selectedResourceType,
    required this.onResourceTypeSelected,
    required this.selectedCustomResource,
    required this.onCustomResourceSelected,
    required this.kubernetesClient,
  });

  final ResourceType selectedResourceType;
  final Function(ResourceType) onResourceTypeSelected;
  final CustomResourceDefinitionInfo? selectedCustomResource;
  final Function(CustomResourceDefinitionInfo?) onCustomResourceSelected;
  final Kubernetes kubernetesClient;

  @override
  State<ResourceMenu> createState() => _ResourceMenuState();
}

class _ResourceMenuState extends State<ResourceMenu> {
  bool _isCustomResourcesExpanded = false;
  List<CustomResourceDefinitionInfo> _crds = [];
  bool _isLoadingCRDs = false;
  Map<String, bool> _groupExpansionState = {};

  @override
  void initState() {
    super.initState();
    _loadCRDs();
  }

  /// Loads the list of Custom Resource Definitions
  Future<void> _loadCRDs() async {
    setState(() {
      _isLoadingCRDs = true;
    });

    try {
      final crds = await CustomResourceService.fetchCRDs(widget.kubernetesClient);
      if (mounted) {
        setState(() {
          _crds = crds;
          _isLoadingCRDs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading CRDs: $e');
      if (mounted) {
        setState(() {
          _isLoadingCRDs = false;
        });
      }
    }
  }

  /// Groups CRDs by their API group
  Map<String, List<CustomResourceDefinitionInfo>> _groupCRDsByApiGroup() {
    final groups = <String, List<CustomResourceDefinitionInfo>>{};

    for (var crd in _crds) {
      final group = crd.group.isEmpty ? 'Core' : crd.group;
      if (!groups.containsKey(group)) {
        groups[group] = [];
      }
      groups[group]!.add(crd);
    }

    // Sort CRDs within each group by kind
    for (var group in groups.keys) {
      groups[group]!.sort((a, b) => a.kind.compareTo(b.kind));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Resources',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),

          // Pods menu item
          _buildMenuItem(
            context: context,
            icon: Icons.widgets,
            label: 'Pods',
            resourceType: ResourceType.pods,
          ),

          // Deployments menu item
          _buildMenuItem(
            context: context,
            icon: Icons.apps,
            label: 'Deployments',
            resourceType: ResourceType.deployments,
          ),

          // Cron Jobs menu item
          _buildMenuItem(
            context: context,
            icon: Icons.schedule,
            label: 'Cron Jobs',
            resourceType: ResourceType.cronJobs,
          ),

          // Secrets menu item
          _buildMenuItem(
            context: context,
            icon: Icons.lock,
            label: 'Secrets',
            resourceType: ResourceType.secrets,
          ),

          const Divider(height: 1),

          // Custom Resources expandable section
          _buildCustomResourcesSection(),
        ],
      ),
    );
  }

  /// Builds the collapsible custom resources section
  Widget _buildCustomResourcesSection() {
    return ExpansionTile(
      leading: Icon(
        Icons.extension,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        'Custom Resources',
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      initiallyExpanded: _isCustomResourcesExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          _isCustomResourcesExpanded = expanded;
        });
      },
      children: [
        if (_isLoadingCRDs)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_crds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No custom resources found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._buildGroupedCustomResources(),
      ],
    );
  }

  /// Builds the grouped custom resources by API group
  List<Widget> _buildGroupedCustomResources() {
    final groups = _groupCRDsByApiGroup();
    final sortedGroupNames = groups.keys.toList()..sort();

    return sortedGroupNames.map((groupName) {
      final crdsInGroup = groups[groupName]!;
      final isExpanded = _groupExpansionState[groupName] ?? false;

      return Tooltip(
        message: groupName,
        waitDuration: const Duration(milliseconds: 500),
        child: ExpansionTile(
          key: Key('group_$groupName'),
          tilePadding: const EdgeInsets.only(left: 24, right: 8),
          childrenPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            groupName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _groupExpansionState[groupName] = expanded;
            });
          },
          children: crdsInGroup.map((crd) => _buildCustomResourceMenuItem(crd)).toList(),
        ),
      );
    }).toList();
  }

  /// Builds a menu item for a custom resource
  Widget _buildCustomResourceMenuItem(CustomResourceDefinitionInfo crd) {
    final isSelected = widget.selectedResourceType == ResourceType.customResource &&
        widget.selectedCustomResource?.name == crd.name;

    return Tooltip(
      message: '${crd.kind} (${crd.apiVersion})',
      waitDuration: const Duration(milliseconds: 500),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 48, right: 8),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(
          crd.kind,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        onTap: () {
          widget.onResourceTypeSelected(ResourceType.customResource);
          widget.onCustomResourceSelected(crd);
        },
      ),
    );
  }

  /// Builds a single menu item
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required ResourceType resourceType,
  }) {
    final isSelected = widget.selectedResourceType == resourceType;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        onTap: () {
          widget.onResourceTypeSelected(resourceType);
          widget.onCustomResourceSelected(null);
        },
      ),
    );
  }
}

