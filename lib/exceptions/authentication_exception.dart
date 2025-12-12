/// Custom exception for Kubernetes authentication failures
class AuthenticationException implements Exception {
  final String message;
  final String authPlugin;
  final String cloudPlatform;
  final String originalError;

  AuthenticationException(
    this.message,
    this.authPlugin,
    this.cloudPlatform,
    this.originalError,
  );

  @override
  String toString() => message;

  /// Returns a user-friendly error message with instructions
  String getUserFriendlyMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Authentication Failed');
    buffer.writeln();
    buffer.writeln('Unable to authenticate with $cloudPlatform.');
    buffer.writeln();
    buffer.writeln('The authentication plugin "$authPlugin" failed to execute.');
    buffer.writeln();
    buffer.writeln('To fix this issue:');
    buffer.writeln();
    
    // Platform-specific instructions
    if (cloudPlatform.contains('Google Cloud')) {
      buffer.writeln('1. Install the GKE auth plugin:');
      buffer.writeln('   gcloud components install gke-gcloud-auth-plugin');
      buffer.writeln();
      buffer.writeln('2. Update gcloud components:');
      buffer.writeln('   gcloud components update');
      buffer.writeln();
      buffer.writeln('3. Authenticate with Google Cloud:');
      buffer.writeln('   gcloud auth login');
      buffer.writeln('   gcloud auth application-default login');
    } else if (cloudPlatform.contains('Amazon Web Services')) {
      buffer.writeln('1. Install AWS CLI and aws-iam-authenticator');
      buffer.writeln();
      buffer.writeln('2. Configure AWS credentials:');
      buffer.writeln('   aws configure');
      buffer.writeln();
      buffer.writeln('3. Update your kubeconfig:');
      buffer.writeln('   aws eks update-kubeconfig --name <cluster-name>');
    } else if (cloudPlatform.contains('Microsoft Azure')) {
      buffer.writeln('1. Install Azure CLI');
      buffer.writeln();
      buffer.writeln('2. Login to Azure:');
      buffer.writeln('   az login');
      buffer.writeln();
      buffer.writeln('3. Get AKS credentials:');
      buffer.writeln('   az aks get-credentials --resource-group <rg> --name <cluster>');
    } else {
      buffer.writeln('1. Ensure the authentication plugin is installed');
      buffer.writeln('2. Verify your cloud provider credentials are configured');
      buffer.writeln('3. Update your kubeconfig file');
    }
    
    buffer.writeln();
    buffer.writeln('After fixing the authentication, restart the application or switch to a different context.');
    
    return buffer.toString();
  }

  /// Returns a short summary for display in error dialogs
  String getShortMessage() {
    return 'Authentication failed for $cloudPlatform. The "$authPlugin" plugin is not configured correctly.';
  }
}

