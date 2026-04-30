import 'dart:async';
import 'package:flutter/material.dart';
import '../exceptions/connection_exception.dart';

/// Connection state used by [ConnectionErrorManager].
enum ConnectionState {
  /// Cluster connection is healthy, watchers poll normally.
  connected,

  /// A connection error has been detected and we are silently retrying in the
  /// background while watchers are paused. The UI shows a small banner.
  reconnecting,

  /// Reconnection attempts have failed for long enough that we surface the
  /// full-screen blocking dialog and require manual user action.
  failed,
}

/// Handle returned by [ConnectionErrorManager.registerWatcher] so a watcher
/// can be unregistered when its stream is cancelled.
class WatcherHandle {
  WatcherHandle({required this.pause, required this.resume});

  final VoidCallback pause;
  final VoidCallback resume;
}

/// Global manager for handling Kubernetes connection errors.
///
/// Watchers register a pause/resume pair. When a connection error is detected
/// (by any watcher) the manager pauses every watcher and starts probing the
/// cluster on a back-off schedule. As soon as a probe succeeds the watchers
/// are resumed — they keep their last successful payload, so lists do not
/// reset and only re-render when the data has actually changed.
///
/// Only if reconnection keeps failing past [_failureThreshold] do we escalate
/// to the blocking error dialog.
class ConnectionErrorManager extends ChangeNotifier {
  static final ConnectionErrorManager _instance = ConnectionErrorManager._internal();
  factory ConnectionErrorManager() => _instance;
  ConnectionErrorManager._internal();

  // Back-off schedule for reconnection attempts (clamped at the last value).
  static const List<Duration> _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  // After this much continuous failure we escalate to the full dialog.
  static const Duration _failureThreshold = Duration(seconds: 30);

  ConnectionState _state = ConnectionState.connected;
  ConnectionException? _currentError;

  final List<WatcherHandle> _watchers = [];

  VoidCallback? _onRetry;
  Future<bool> Function()? _healthCheck;

  Timer? _retryTimer;
  int _retryAttempt = 0;
  DateTime? _firstFailureTime;

  ConnectionState get state => _state;
  ConnectionException? get currentError => _currentError;
  bool get isReconnecting => _state == ConnectionState.reconnecting;
  bool get isShowingError => _state == ConnectionState.failed;

  /// Registers pause/resume callbacks for a watcher. The returned handle
  /// must be passed to [unregisterWatcher] when the watcher is cancelled.
  WatcherHandle registerWatcher({
    required VoidCallback pause,
    required VoidCallback resume,
  }) {
    final handle = WatcherHandle(pause: pause, resume: resume);
    _watchers.add(handle);
    // If we are already in a degraded state, pause this watcher immediately
    // so it does not start hammering a broken connection.
    if (_state != ConnectionState.connected) {
      try {
        pause();
      } catch (e) {
        debugPrint('Error pausing newly registered watcher: $e');
      }
    }
    return handle;
  }

  /// Unregisters a previously registered watcher handle.
  void unregisterWatcher(WatcherHandle? handle) {
    if (handle == null) return;
    _watchers.remove(handle);
  }

  /// Sets the manual retry callback used when the user clicks "Retry" on the
  /// blocking dialog.
  void setRetryCallback(VoidCallback callback) {
    _onRetry = callback;
  }

  /// Registers the lightweight health-check used to probe whether the cluster
  /// is reachable again. Should return `true` when the connection is healthy.
  void setHealthCheck(Future<bool> Function() healthCheck) {
    _healthCheck = healthCheck;
  }

  /// Reports a connection error from a watcher. Returns `true` if the error
  /// was a connection error and was handled (caller should stop polling).
  bool checkAndHandleError(Object error) {
    final connectionError = ConnectionException.fromError(error);
    if (connectionError != null) {
      _enterReconnecting(connectionError);
      return true;
    }
    return false;
  }

  /// Enters the reconnecting state and starts the back-off retry loop.
  void _enterReconnecting(ConnectionException error) {
    _currentError = error;

    if (_state == ConnectionState.connected) {
      debugPrint('Connection error detected, entering reconnecting state: ${error.message}');
      _state = ConnectionState.reconnecting;
      _firstFailureTime = DateTime.now();
      _retryAttempt = 0;
      _pauseAllWatchers();
      notifyListeners();
      _scheduleNextProbe();
    } else if (_state == ConnectionState.reconnecting) {
      // Already reconnecting; just make sure a probe is scheduled.
      if (_retryTimer == null || !_retryTimer!.isActive) {
        _scheduleNextProbe();
      }
    }
    // If already in `failed`, leave the dialog up.
  }

  void _pauseAllWatchers() {
    for (final w in List<WatcherHandle>.from(_watchers)) {
      try {
        w.pause();
      } catch (e) {
        debugPrint('Error pausing watcher: $e');
      }
    }
  }

  void _resumeAllWatchers() {
    for (final w in List<WatcherHandle>.from(_watchers)) {
      try {
        w.resume();
      } catch (e) {
        debugPrint('Error resuming watcher: $e');
      }
    }
  }

  void _scheduleNextProbe() {
    final delay = _backoff[_retryAttempt.clamp(0, _backoff.length - 1)];
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _runProbe);
  }

  Future<void> _runProbe() async {
    if (_state != ConnectionState.reconnecting) return;

    bool ok = false;
    try {
      ok = await (_healthCheck?.call() ?? Future.value(false));
    } catch (e) {
      debugPrint('Health check threw: $e');
      ok = false;
    }

    if (_state != ConnectionState.reconnecting) return;

    if (ok) {
      _onReconnected();
    } else {
      final firstFailure = _firstFailureTime;
      if (firstFailure != null &&
          DateTime.now().difference(firstFailure) >= _failureThreshold) {
        _escalateToFailed();
      } else {
        _scheduleNextProbe();
      }
    }
  }

  void _onReconnected() {
    debugPrint('Connection restored, resuming watchers');
    _retryTimer?.cancel();
    _retryTimer = null;
    _state = ConnectionState.connected;
    _currentError = null;
    _retryAttempt = 0;
    _firstFailureTime = null;
    _resumeAllWatchers();
    notifyListeners();
  }

  void _escalateToFailed() {
    debugPrint('Reconnection failed for too long, showing blocking dialog');
    _retryTimer?.cancel();
    _retryTimer = null;
    _state = ConnectionState.failed;
    notifyListeners();
  }

  /// Manual retry triggered by the user from the full error dialog.
  void retry() {
    debugPrint('Manual retry requested');
    _retryTimer?.cancel();
    _retryTimer = null;
    _state = ConnectionState.reconnecting;
    _retryAttempt = 0;
    _firstFailureTime = DateTime.now();
    _currentError = null;
    notifyListeners();

    // Give the host a chance to fully reinitialize (new client, etc.).
    _onRetry?.call();

    // Also probe immediately.
    _scheduleNextProbe();
  }

  /// Clears the current error without retrying. Used when the host has
  /// successfully re-established a connection itself (e.g. context switch).
  void clearError() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_state != ConnectionState.connected) {
      _state = ConnectionState.connected;
      _currentError = null;
      _retryAttempt = 0;
      _firstFailureTime = null;
      _resumeAllWatchers();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _watchers.clear();
    super.dispose();
  }
}
