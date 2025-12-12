import 'package:flutter/material.dart';

/// Left drawer widget for selecting Kubernetes contexts
class ContextDrawer extends StatelessWidget {
  final List<String> availableContexts;
  final String activeContext;
  final Function(String) onContextSelected;

  const ContextDrawer({
    super.key,
    required this.availableContexts,
    required this.activeContext,
    required this.onContextSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 450,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // No rounded corners
      ),
      child: Column(
        children: [
          // Close button at the top
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context); // Close the drawer
              },
              tooltip: 'Close',
            ),
          ),
          // Scrollable list of contexts
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Map each context to a ListTile
                ...availableContexts.map((contextName) {
                  final isSelected = contextName == activeContext;
                  return ListTile(
                    // Show check icon for selected context, outline for others
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                    // Display context name with styling
                    title: Text(
                      contextName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    selected: isSelected,
                    // Handle context selection
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      onContextSelected(contextName); // Notify parent
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

