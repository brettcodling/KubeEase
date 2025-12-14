import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Represents an active port forward session
class PortForwardSession {
  final String id;
  final String namespace;
  final String podName;
  final String containerPort;
  final String localPort;
  final Process process;
  final DateTime startTime;

  PortForwardSession({
    required this.id,
    required this.namespace,
    required this.podName,
    required this.containerPort,
    required this.localPort,
    required this.process,
    required this.startTime,
  });

  String get displayName => '$podName:$containerPort → localhost:$localPort';
}

/// Manages port forward sessions
class PortForwardManager extends ChangeNotifier {
  static final PortForwardManager _instance = PortForwardManager._internal();
  factory PortForwardManager() => _instance;
  PortForwardManager._internal();

  final Map<String, PortForwardSession> _sessions = {};

  List<PortForwardSession> get sessions => _sessions.values.toList();

  /// Check if a port forward exists for a specific pod and port
  bool isPortForwarded(String namespace, String podName, String containerPort) {
    return _sessions.values.any((s) =>
        s.namespace == namespace &&
        s.podName == podName &&
        s.containerPort == containerPort);
  }

  /// Get session for a specific pod and port
  PortForwardSession? getSessionForPort(String namespace, String podName, String containerPort) {
    try {
      return _sessions.values.firstWhere(
        (s) =>
            s.namespace == namespace &&
            s.podName == podName &&
            s.containerPort == containerPort,
      );
    } catch (e) {
      return null;
    }
  }

  /// Starts a port forward session
  Future<void> startPortForward({
    required String namespace,
    required String podName,
    required String containerPort,
    required String localPort,
  }) async {
    final id = 'pf-$namespace-$podName-$containerPort-$localPort-${DateTime.now().millisecondsSinceEpoch}';

    // Check if port is already in use
    if (_sessions.values.any((s) => s.localPort == localPort)) {
      throw Exception('Local port $localPort is already in use by another port forward');
    }

    try {
      // Start kubectl port-forward process
      final process = await Process.start(
        'kubectl',
        [
          'port-forward',
          '-n',
          namespace,
          podName,
          '$localPort:$containerPort',
        ],
      );

      // Create session
      final session = PortForwardSession(
        id: id,
        namespace: namespace,
        podName: podName,
        containerPort: containerPort,
        localPort: localPort,
        process: process,
        startTime: DateTime.now(),
      );

      _sessions[id] = session;
      notifyListeners();

      // Listen for process exit
      process.exitCode.then((exitCode) {
        _sessions.remove(id);
        notifyListeners();
      });

      // Listen to stderr for errors (silently consume)
      process.stderr.listen((data) {
        // Consume stderr to prevent buffer issues
      });

      // Listen to stdout (silently consume)
      process.stdout.listen((data) {
        // Consume stdout to prevent buffer issues
      });
    } catch (e) {
      throw Exception('Failed to start port forward: $e');
    }
  }

  /// Stops a port forward session
  Future<void> stopPortForward(String id) async {
    final session = _sessions[id];
    if (session == null) return;

    session.process.kill();
    _sessions.remove(id);
    notifyListeners();
  }

  /// Stops all port forward sessions
  Future<void> stopAll() async {
    for (final session in _sessions.values) {
      session.process.kill();
    }
    _sessions.clear();
    notifyListeners();
  }

  /// Cleanup all sessions on app close
  @override
  void dispose() {
    stopAll();
    super.dispose();
  }

  /// Gets a session by ID
  PortForwardSession? getSession(String id) => _sessions[id];

  /// Checks if a local port is in use
  bool isLocalPortInUse(String port) {
    return _sessions.values.any((s) => s.localPort == port);
  }
}

