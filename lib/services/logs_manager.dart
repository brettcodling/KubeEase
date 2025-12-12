import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';

/// Represents a single logs session
class LogsSession {
  final String id;
  final String title;
  final Kubernetes kubernetesClient;
  final String namespace;
  final String jobName;
  final String? containerName;
  final bool isPodLog;
  bool isMinimized;

  LogsSession({
    required this.id,
    required this.title,
    required this.kubernetesClient,
    required this.namespace,
    required this.jobName,
    this.containerName,
    this.isPodLog = false,
    this.isMinimized = false,
  });
}

/// Singleton service to manage multiple logs sessions
class LogsManager extends ChangeNotifier {
  static final LogsManager _instance = LogsManager._internal();
  
  factory LogsManager() => _instance;
  
  LogsManager._internal();

  final List<LogsSession> _sessions = [];
  LogsSession? _activeSession;

  List<LogsSession> get sessions => List.unmodifiable(_sessions);
  List<LogsSession> get minimizedSessions => _sessions.where((s) => s.isMinimized).toList();
  LogsSession? get activeSession => _activeSession;
  int get minimizedCount => minimizedSessions.length;

  /// Opens a new logs session or restores an existing one
  void openLogs({
    required String id,
    required String title,
    required Kubernetes kubernetesClient,
    required String namespace,
    required String jobName,
    String? containerName,
    bool isPodLog = false,
  }) {
    // Check if session already exists
    final existingIndex = _sessions.indexWhere((s) => s.id == id);
    
    if (existingIndex != -1) {
      // Restore existing session
      final session = _sessions[existingIndex];
      session.isMinimized = false;
      _activeSession = session;
    } else {
      // Create new session
      final session = LogsSession(
        id: id,
        title: title,
        kubernetesClient: kubernetesClient,
        namespace: namespace,
        jobName: jobName,
        containerName: containerName,
        isPodLog: isPodLog,
        isMinimized: false,
      );
      _sessions.add(session);
      _activeSession = session;
    }
    
    notifyListeners();
  }

  /// Minimizes the active session
  void minimizeActive() {
    if (_activeSession != null) {
      _activeSession!.isMinimized = true;
      _activeSession = null;
      notifyListeners();
    }
  }

  /// Restores a minimized session
  void restoreSession(String id) {
    final session = _sessions.firstWhere((s) => s.id == id);
    session.isMinimized = false;
    _activeSession = session;
    notifyListeners();
  }

  /// Closes a session completely
  void closeSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    if (_activeSession?.id == id) {
      _activeSession = null;
    }
    notifyListeners();
  }

  /// Closes the active session
  void closeActive() {
    if (_activeSession != null) {
      closeSession(_activeSession!.id);
    }
  }
}

