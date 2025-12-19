import 'package:flutter/material.dart';
import '../services/connection_error_manager.dart';

/// Full-screen overlay that displays connection errors
/// This widget listens to the ConnectionErrorManager and shows a blocking
/// dialog when a connection error occurs
class ConnectionErrorOverlay extends StatefulWidget {
  final Widget child;

  const ConnectionErrorOverlay({
    super.key,
    required this.child,
  });

  @override
  State<ConnectionErrorOverlay> createState() => _ConnectionErrorOverlayState();
}

class _ConnectionErrorOverlayState extends State<ConnectionErrorOverlay> {
  final ConnectionErrorManager _errorManager = ConnectionErrorManager();

  @override
  void initState() {
    super.initState();
    _errorManager.addListener(_onErrorStateChanged);
  }

  @override
  void dispose() {
    _errorManager.removeListener(_onErrorStateChanged);
    super.dispose();
  }

  void _onErrorStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_errorManager.isShowingError && _errorManager.currentError != null)
          _buildErrorDialog(context),
      ],
    );
  }

  Widget _buildErrorDialog(BuildContext context) {
    final error = _errorManager.currentError!;

    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          margin: const EdgeInsets.all(32),
          child: Card(
            elevation: 8,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Error icon
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  
                  // Error title
                  Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Error message
                  Text(
                    error.getShortMessage(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Detailed error information in an expandable section
                  ExpansionTile(
                    title: const Text('Details'),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          error.getUserFriendlyMessage(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Retry button
                  FilledButton.icon(
                    onPressed: () {
                      _errorManager.retry();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

