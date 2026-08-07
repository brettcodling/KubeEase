import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import '../services/auth_refresh_manager.dart';

/// Debug-only popup menu button shown in AppBars across all screens.
/// Rendered only when [kDebugMode] is true; produces an empty [SizedBox]
/// in release builds so callers never need to guard it themselves.
class DebugMenuButton extends StatelessWidget {
  final Kubernetes kubernetesClient;

  const DebugMenuButton({super.key, required this.kubernetesClient});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.bug_report, color: Colors.orange),
      tooltip: 'Debug Menu',
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Debug Options',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'simulate_401',
          child: Row(
            children: [
              Icon(Icons.lock_clock, size: 18),
              SizedBox(width: 8),
              Text('Simulate 401 (bypass HTTP)'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'invalidate_token',
          child: Row(
            children: [
              Icon(Icons.no_encryption_outlined, size: 18),
              SizedBox(width: 8),
              Text('Invalidate Bearer Token (real 401)'),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'simulate_401':
            debugPrint('🧪 User triggered token expiration simulation');
            await AuthRefreshManager().simulateTokenExpiration();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🧪 Simulated 401 error - check console for refresh logs'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            break;
          case 'invalidate_token':
            debugPrint('🧪 User invalidated bearer token');
            AuthRefreshManager().invalidateToken(kubernetesClient);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🧪 Bearer token invalidated — next poll will get a real 401'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            break;
        }
      },
    );
  }
}
