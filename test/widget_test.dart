import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kube_ease/main.dart';

void main() {
  group('KubeEase App', () {
    test('should create app without errors', () {
      // This test verifies the app can be instantiated
      // Note: Full app testing requires mocking Kubernetes API calls
      const app = KubernetesManagerApp();
      expect(app, isNotNull);
    });

    test('should have global navigator key', () {
      expect(KubernetesManagerApp.navigatorKey, isNotNull);
      expect(KubernetesManagerApp.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });
}

