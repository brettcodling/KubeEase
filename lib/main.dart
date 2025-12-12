import 'package:flutter/material.dart';
import 'screens/cluster_view_screen.dart';
import 'widgets/logs_overlay.dart';

/// Entry point of the application
void main() {
  runApp(const KubernetesManagerApp());
}

/// Main application widget for the Kubernetes cluster manager
class KubernetesManagerApp extends StatelessWidget {
  const KubernetesManagerApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: const ClusterViewScreen(),
      builder: (context, child) {
        return LogsOverlay(child: child ?? const SizedBox.shrink());
      },
      debugShowCheckedModeBanner: false,
    );
  }
}