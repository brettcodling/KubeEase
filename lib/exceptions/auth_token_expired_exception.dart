/// Custom exception for expired Kubernetes authentication tokens
class AuthTokenExpiredException implements Exception {
  final String message;
  final Object originalError;

  AuthTokenExpiredException(this.message, this.originalError);

  @override
  String toString() => message;

  /// Checks if an error is a 401 Unauthorized error (expired token)
  static bool isAuthTokenExpired(Object error) {
    final errorString = error.toString();

    // Check for 401 status code in DioException
    if (errorString.contains('DioException') && 
        errorString.contains('status code of 401')) {
      return true;
    }

    // Check for other 401 patterns
    return errorString.contains('401') ||
        errorString.contains('Unauthorized') ||
        errorString.contains('authentication token has expired') ||
        errorString.contains('token is expired');
  }

  /// Creates an AuthTokenExpiredException from any error if it's a 401 error
  static AuthTokenExpiredException? fromError(Object error) {
    if (isAuthTokenExpired(error)) {
      return AuthTokenExpiredException(
        'Kubernetes authentication token has expired. Refreshing credentials...',
        error,
      );
    }
    return null;
  }
}

