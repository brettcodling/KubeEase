import 'dart:io';

/// Custom exception for Kubernetes connection failures
class ConnectionException implements Exception {
  final String message;
  final Object originalError;

  ConnectionException(this.message, this.originalError);

  @override
  String toString() => message;

  /// Checks if an error is a connection error
  static bool isConnectionError(Object error) {
    final errorString = error.toString().toLowerCase();

    // Check for SocketException
    if (error is SocketException) {
      return true;
    }

    // Check for DioException connection/timeout errors
    if (errorString.contains('dioexception')) {
      return errorString.contains('[connection timeout]') ||
          errorString.contains('[receive timeout]') ||
          errorString.contains('[send timeout]') ||
          errorString.contains('[connection error]') ||
          errorString.contains('[bad response]') ||
          errorString.contains('[cancel]');
    }

    // Check for common connection error patterns
    return errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed') ||
        errorString.contains('connection timeout') ||
        errorString.contains('connection timed out') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no route to host') ||
        errorString.contains('failed to connect') ||
        errorString.contains('connection error') ||
        errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('os error: connection refused') ||
        errorString.contains('handshake exception');
  }

  /// Creates a ConnectionException from any error if it's a connection error
  static ConnectionException? fromError(Object error) {
    if (isConnectionError(error)) {
      return ConnectionException(
        'Failed to connect to Kubernetes cluster. Please check your network connection and cluster availability.',
        error,
      );
    }
    return null;
  }

  /// Returns a user-friendly error message
  String getUserFriendlyMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Connection Error');
    buffer.writeln();
    buffer.writeln('Unable to connect to the Kubernetes cluster.');
    buffer.writeln();
    buffer.writeln('Possible causes:');
    buffer.writeln('• The cluster is not running or unreachable');
    buffer.writeln('• Network connectivity issues');
    buffer.writeln('• VPN connection is required but not active');
    buffer.writeln('• Firewall blocking the connection');
    buffer.writeln('• Incorrect cluster endpoint in kubeconfig');
    buffer.writeln();
    buffer.writeln('Please verify:');
    buffer.writeln('1. Your network connection is active');
    buffer.writeln('2. The cluster is running and accessible');
    buffer.writeln('3. VPN is connected if required');
    buffer.writeln('4. Firewall settings allow the connection');
    
    return buffer.toString();
  }

  /// Returns a short summary for display
  String getShortMessage() {
    return 'Failed to connect to Kubernetes cluster';
  }
}

