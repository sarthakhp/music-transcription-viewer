import 'package:flutter/material.dart';

/// Busy/error bookkeeping shared by the upload panels: [guarded] shows a busy
/// state around an action and turns a failure into text for [error].
mixin BusyGuard<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;
  double? uploadFraction;

  Future<void> guarded(
    String failure,
    Future<void> Function() action, {
    VoidCallback? onDone,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$failure: $e');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          onDone?.call();
        });
      }
    }
  }
}
