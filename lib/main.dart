import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/cluster_view_screen.dart';
import 'widgets/logs_overlay.dart';
import 'services/port_forward_manager.dart';

/// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set minimum window size
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(800, 600),
    center: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: KubernetesManagerApp.navigatorKey,
      title: '',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: const ClusterViewScreen(),
      builder: (context, child) {
        return SessionOverlay(child: child ?? const SizedBox.shrink());
      },
      debugShowCheckedModeBanner: false,
    );
  }
}