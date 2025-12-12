import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k8s/k8s.dart';
import 'package:xterm/xterm.dart';
import 'package:pty/pty.dart';

/// Type of session
enum SessionType {
  logs,
  terminal,
}

/// Represents a single session (logs or terminal)
class Session {
  final String id;
  final String title;
  final SessionType type;
  final Kubernetes kubernetesClient;
  final String namespace;
  final String podName;
  final String? containerName;
  final bool isPodLog; // Only relevant for logs sessions
  bool isMinimized;

  // Terminal-specific state (preserved across minimize/restore)
  Terminal? terminal;
  PseudoTerminal? pty;
  TerminalController? terminalController;
  StreamSubscription<String>? ptyOutputSubscription;

  Session({
    required this.id,
    required this.title,
    required this.type,
    required this.kubernetesClient,
    required this.namespace,
    required this.podName,
    this.containerName,
    this.isPodLog = false,
    this.isMinimized = false,
    this.terminal,
    this.pty,
    this.terminalController,
    this.ptyOutputSubscription,
  });

  /// Icon to display for this session type
  IconData get icon {
    switch (type) {
      case SessionType.logs:
        return Icons.article_outlined;
      case SessionType.terminal:
        return Icons.terminal;
    }
  }

  /// Clean up resources when session is closed
  void dispose() {
    if (type == SessionType.terminal) {
      ptyOutputSubscription?.cancel();
      pty?.kill();
    }
  }
}

/// Singleton service to manage multiple sessions (logs and terminals)
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  
  factory SessionManager() => _instance;
  
  SessionManager._internal();

  final List<Session> _sessions = [];
  Session? _activeSession;

  List<Session> get sessions => List.unmodifiable(_sessions);
  List<Session> get minimizedSessions => _sessions.where((s) => s.isMinimized).toList();
  Session? get activeSession => _activeSession;
  int get minimizedCount => minimizedSessions.length;

  /// Opens a new logs session or restores an existing one
  void openLogs({
    required String id,
    required String title,
    required Kubernetes kubernetesClient,
    required String namespace,
    required String podName,
    String? containerName,
    bool isPodLog = false,
  }) {
    _openSession(
      id: id,
      title: title,
      type: SessionType.logs,
      kubernetesClient: kubernetesClient,
      namespace: namespace,
      podName: podName,
      containerName: containerName,
      isPodLog: isPodLog,
    );
  }

  /// Opens a new terminal session or restores an existing one
  void openTerminal({
    required String id,
    required String title,
    required Kubernetes kubernetesClient,
    required String namespace,
    required String podName,
    String? containerName,
  }) {
    _openSession(
      id: id,
      title: title,
      type: SessionType.terminal,
      kubernetesClient: kubernetesClient,
      namespace: namespace,
      podName: podName,
      containerName: containerName,
    );
  }

  /// Internal method to open or restore a session
  void _openSession({
    required String id,
    required String title,
    required SessionType type,
    required Kubernetes kubernetesClient,
    required String namespace,
    required String podName,
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
      final session = Session(
        id: id,
        title: title,
        type: type,
        kubernetesClient: kubernetesClient,
        namespace: namespace,
        podName: podName,
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
    final session = _sessions.firstWhere((s) => s.id == id);
    session.dispose(); // Clean up resources
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

