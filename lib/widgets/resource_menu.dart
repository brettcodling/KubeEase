import 'package:flutter/material.dart';

/// Enum representing the different resource types available
enum ResourceType {
  pods,
  deployments,
  cronJobs,
  secrets,
}

/// Left sidebar menu widget for selecting Kubernetes resource types
class ResourceMenu extends StatelessWidget {
  const ResourceMenu({
    super.key,
    required this.selectedResourceType,
    required this.onResourceTypeSelected,
  });

  final ResourceType selectedResourceType;
  final Function(ResourceType) onResourceTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
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
        ],
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
    final isSelected = selectedResourceType == resourceType;
    
    return ListTile(
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
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      onTap: () => onResourceTypeSelected(resourceType),
    );
  }
}

