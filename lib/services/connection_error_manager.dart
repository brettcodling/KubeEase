import 'dart:async';
import 'package:flutter/material.dart';
import '../exceptions/connection_exception.dart';

/// Connection state used by [ConnectionErrorManager].
enum ConnectionState {
  /// Cluster is reachable; watchers poll normally.
  connected,

  /// A connection error was detected; silently probing in the background.
  /// The UI shows a small non-blocking banner.
  reconnecting,

  /// Probing has failed for longer than [_failureThreshold]; the full-screen
  /// blocking dialog is shown and requires manual user action.
  failed,
}

/// Global singleton that tracks Kubernetes connection health.
///
/// Watchers simply call [reportConnectionError] when they catch a network
/// error, and check [isConnected] before each poll so they silently skip
/// calls while the cluster is unreachable. No watcher registration or
/// pause/resume callbacks are needed.
///
/// A lightweight health-check ([setHealthCheck]) is probed on a back-off
/// schedule. When the probe succeeds the state returns to [connected] and
/// the next poll cycle resumes automatically.
class ConnectionErrorManager extends ChangeNotifier {
  static final ConnectionErrorManager _instance = ConnectionErrorManager._internal();
  factory ConnectionErrorManager() => _instance;
  ConnectionErrorManager._internal();

  static const List<Duration> _backoff = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  static const Duration _failureThreshold = Duration(seconds: 30);

  ConnectionState _state = ConnectionState.connected;
  ConnectionException? _currentError;
  Timer? _probeTimer;
  int _probeAttempt = 0;
  DateTime? _firstFailureTime;
  Future<bool> Function()? _healthCheck;

  ConnectionState get state => _state;
  ConnectionException? get currentError => _currentError;
  bool get isConnected => _state == ConnectionState.connected;
  bool get isReconnecting => _state == ConnectionState.reconnecting;
  bool get isShowingError => _state == ConnectionState.failed;

  /// Registers the lightweight health-check used to probe whether the cluster
  /// is reachable again. Should return `true` when the connection is healthy.
  void setHealthCheck(Future<bool> Function() healthCheck) {
    _healthCheck = healthCheck;
  }

  /// Called by watchers when they catch an error. Returns `true` if the error
  /// was a connection error (caller can skip further error handling).
  ///
  /// When transitioning from [connected] → [reconnecting] for the first time,
  /// the back-off probe loop is started automatically.
  bool reportConnectionError(Object error) {
    final connectionError = ConnectionException.fromError(error);
    if (connectionError == null) return false;

    if (_state == ConnectionState.connected) {
      debugPrint('Connection error detected: ${connectionError.message}');
      _state = ConnectionState.reconnecting;
      _currentError = connectionError;
      _firstFailureTime = DateTime.now();
      _probeAttempt = 0;
      notifyListeners();
      _scheduleProbe();
    }
    // Already reconnecting or failed — keep existing state.
    return true;
  }

  void _scheduleProbe() {
    _probeTimer?.cancel();
    final delay = _backoff[_probeAttempt.clamp(0, _backoff.length - 1)];
    _probeAttempt++;
    _probeTimer = Timer(delay, _probe);
  }

  Future<void> _probe() async {
    if (_state != ConnectionState.reconnecting) return;

    bool ok = false;
    try {
      ok = await (_healthCheck?.call() ?? Future.value(false));
    } catch (_) {}

    if (_state != ConnectionState.reconnecting) return;

    if (ok) {
      debugPrint('Connection restored');
      _state = ConnectionState.connected;
      _currentError = null;
      _probeAttempt = 0;
      _firstFailureTime = null;
      _probeTimer = null;
      notifyListeners();
    } else if (DateTime.now().difference(_firstFailureTime!) >= _failureThreshold) {
      debugPrint('Reconnection failed for too long, showing error dialog');
      _state = ConnectionState.failed;
      _probeTimer = null;
      notifyListeners();
    } else {
      _scheduleProbe();
    }
  }

  /// User-triggered retry from the full error dialog.
  void retry() {
    debugPrint('Manual retry requested');
    _probeTimer?.cancel();
    _state = ConnectionState.reconnecting;
    _currentError = null;
    _probeAttempt = 0;
    _firstFailureTime = DateTime.now();
    notifyListeners();
    _scheduleProbe();
  }

  /// Clears error state without retrying. Call this after a successful
  /// context switch or manual reconnect so watchers resume cleanly.
  void clearError() {
    _probeTimer?.cancel();
    _probeTimer = null;
    if (_state != ConnectionState.connected) {
      _state = ConnectionState.connected;
      _currentError = null;
      _probeAttempt = 0;
      _firstFailureTime = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    super.dispose();
  }
}
