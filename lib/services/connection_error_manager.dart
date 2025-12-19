import 'package:flutter/material.dart';
import '../exceptions/connection_exception.dart';

/// Global manager for handling Kubernetes connection errors
/// This singleton manages the display of connection error dialogs and coordinates
/// the cancellation of all active watchers when a connection error occurs
class ConnectionErrorManager extends ChangeNotifier {
  static final ConnectionErrorManager _instance = ConnectionErrorManager._internal();
  factory ConnectionErrorManager() => _instance;
  ConnectionErrorManager._internal();

  // Current connection error state
  ConnectionException? _currentError;
  bool _isShowingError = false;
  
  // Callbacks for retry and cancel operations
  VoidCallback? _onRetry;
  final List<VoidCallback> _watcherCancelCallbacks = [];

  ConnectionException? get currentError => _currentError;
  bool get isShowingError => _isShowingError;

  /// Registers a watcher cancel callback
  /// This should be called by any component that creates a Kubernetes watcher
  void registerWatcherCancelCallback(VoidCallback callback) {
    _watcherCancelCallbacks.add(callback);
  }

  /// Unregisters a watcher cancel callback
  void unregisterWatcherCancelCallback(VoidCallback callback) {
    _watcherCancelCallbacks.remove(callback);
  }

  /// Sets the retry callback
  void setRetryCallback(VoidCallback callback) {
    _onRetry = callback;
  }

  /// Handles a connection error
  /// This will cancel all watchers and show the error dialog
  void handleConnectionError(ConnectionException error) {
    if (_isShowingError) {
      // Already showing an error, don't show another one
      return;
    }

    debugPrint('Connection error detected: ${error.message}');
    
    // Cancel all active watchers
    _cancelAllWatchers();

    // Set error state
    _currentError = error;
    _isShowingError = true;
    notifyListeners();
  }

  /// Cancels all registered watchers
  void _cancelAllWatchers() {
    debugPrint('Cancelling ${_watcherCancelCallbacks.length} active watchers');
    for (final callback in _watcherCancelCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error cancelling watcher: $e');
      }
    }
    _watcherCancelCallbacks.clear();
  }

  /// Handles retry action
  void retry() {
    debugPrint('Retrying connection...');
    _currentError = null;
    _isShowingError = false;
    notifyListeners();
    
    // Call the retry callback if set
    _onRetry?.call();
  }

  /// Clears the current error without retrying
  void clearError() {
    _currentError = null;
    _isShowingError = false;
    notifyListeners();
  }

  /// Checks if an error is a connection error and handles it if so
  /// Returns true if it was a connection error, false otherwise
  bool checkAndHandleError(Object error) {
    final connectionError = ConnectionException.fromError(error);
    if (connectionError != null) {
      handleConnectionError(connectionError);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _cancelAllWatchers();
    super.dispose();
  }
}

