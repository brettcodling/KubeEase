import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/cluster_view_screen.dart';
import 'widgets/logs_overlay.dart';
import 'widgets/connection_error_overlay.dart';
import 'services/port_forward_manager.dart';
import 'services/connection_error_manager.dart';

/// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set minimum window size
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(800, 600),
    center: true,
    title: 'KubeEase',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('KubeEase');
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const KubernetesManagerApp());
}

/// Main application widget for the Kubernetes cluster manager
class KubernetesManagerApp extends StatefulWidget {
  const KubernetesManagerApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<KubernetesManagerApp> createState() => _KubernetesManagerAppState();
}

class _KubernetesManagerAppState extends State<KubernetesManagerApp> {
  @override
  void dispose() {
    PortForwardManager().dispose();
    ConnectionErrorManager().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: KubernetesManagerApp.navigatorKey,
      title: 'KubeEase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: const ClusterViewScreen(),
      builder: (context, child) {
        // Wrap with connection error overlay first, then session overlay
        return ConnectionErrorOverlay(
          child: SessionOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}