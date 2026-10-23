import 'package:flutter/material.dart';
import '../../../utils/friendly_error.dart';

/// Busy/error bookkeeping shared by the upload panels: [guarded] shows a busy
/// state around an action and turns a failure into a plain sentence for [error].
/// [failure] finishes "while trying to ...", for example "upload this song".
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
      if (mounted) setState(() => error = explainError(e, during: failure).message);
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
