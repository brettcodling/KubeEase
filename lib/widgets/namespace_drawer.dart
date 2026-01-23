import 'package:flutter/material.dart';

/// Right drawer widget for selecting Kubernetes namespaces
class NamespaceDrawer extends StatefulWidget {
  final List<String> availableNamespaces;
  final Set<String> selectedNamespaces;
  final bool isLoadingNamespaces;
  final Function(Set<String>) onSelectionChanged;

  const NamespaceDrawer({
    super.key,
    required this.availableNamespaces,
    required this.selectedNamespaces,
    required this.isLoadingNamespaces,
    required this.onSelectionChanged,
  });

  @override
  State<NamespaceDrawer> createState() => _NamespaceDrawerState();
}

class _NamespaceDrawerState extends State<NamespaceDrawer> {
  String namespaceSearchQuery = ''; // Search query for filtering namespaces
  late Set<String> _selectedNamespaces;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedNamespaces = Set.from(widget.selectedNamespaces);
    // Auto-focus the search box when the drawer opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NamespaceDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state if parent state changes
    if (oldWidget.selectedNamespaces != widget.selectedNamespaces) {
      _selectedNamespaces = Set.from(widget.selectedNamespaces);
    }
  }

  void _updateSelection(Set<String> newSelection) {
    setState(() {
      _selectedNamespaces = newSelection;
    });
    widget.onSelectionChanged(newSelection);
  }

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
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () {
                  Navigator.pop(context); // Close the drawer
                },
              ),
            ),
          ),
          // Search box for filtering namespaces
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search namespaces...',
                prefixIcon: const Icon(Icons.search),
                // Show clear button only when there's text
                suffixIcon: namespaceSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            namespaceSearchQuery = ''; // Clear search query
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                isDense: true, // Compact design
              ),
              onChanged: (value) {
                setState(() {
                  namespaceSearchQuery = value; // Update search query
                });
              },
            ),
          ),
          const Divider(height: 1),
          // "Select All" checkbox
          CheckboxListTile(
            title: const Text('Select All'),
            // Checked if all namespaces are selected
            value: _selectedNamespaces.length == widget.availableNamespaces.length &&
                widget.availableNamespaces.isNotEmpty,
            onChanged: (bool? checked) {
              if (checked == true) {
                // Select all namespaces
                _updateSelection(Set.from(widget.availableNamespaces));
              } else {
                // Deselect all namespaces
                _updateSelection({});
              }
            },
            controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
          ),
          const Divider(height: 1),
          // Main content area: loading indicator or namespace list
          Expanded(
            child: widget.isLoadingNamespaces
                // Show loading spinner while fetching namespaces
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading namespaces...'),
                      ],
                    ),
                  )
                // Show namespace list when loaded
                : _buildNamespaceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNamespaceList() {
    // Filter namespaces based on search query (case-insensitive)
    final filteredNamespaces = widget.availableNamespaces
        .where((ns) => ns.toLowerCase().contains(namespaceSearchQuery.toLowerCase()))
        .toList();

    // Sort namespaces: selected ones first, then alphabetically within each group
    filteredNamespaces.sort((a, b) {
      final aSelected = _selectedNamespaces.contains(a);
      final bSelected = _selectedNamespaces.contains(b);

      // If one is selected and the other isn't, selected comes first
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;

      // If both have the same selection status, sort alphabetically
      return a.compareTo(b);
    });

    // Show empty state if no namespaces match
    if (filteredNamespaces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            namespaceSearchQuery.isEmpty
                ? 'No namespaces available'
                : 'No namespaces match "$namespaceSearchQuery"',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    // Display list of namespaces with checkboxes
    return ListView(
      padding: EdgeInsets.zero,
      children: filteredNamespaces.map((namespace) {
        return CheckboxListTile(
          title: Text(namespace),
          value: _selectedNamespaces.contains(namespace),
          onChanged: (bool? checked) {
            final newSelection = Set<String>.from(_selectedNamespaces);
            if (checked == true) {
              // Add namespace to selection
              newSelection.add(namespace);
            } else {
              // Remove namespace from selection
              newSelection.remove(namespace);
            }
            _updateSelection(newSelection);
          },
          controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
        );
      }).toList(),
    );
  }
}

