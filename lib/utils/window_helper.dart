import 'package:flutter/material.dart';

/// Helper class for opening content in dialogs
class WindowHelper {
  /// Opens a widget in a full-screen dialog
  static Future<void> openInDialog({
    required BuildContext context,
    required String title,
    required Widget child,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: child,
        ),
      ),
    );
  }
}

