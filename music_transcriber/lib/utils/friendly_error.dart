import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// An error as the person should see it: a plain sentence saying what happened
/// and what to do, with the technical text kept aside for anyone who wants it.
class FriendlyError {
  final String message;
  final String? details;
  const FriendlyError(this.message, [this.details]);
}

/// Turns whatever was thrown while doing [during] (for example "upload this
/// song") into a [FriendlyError]. Unknown errors still get a plain first
/// sentence; the raw text goes in [FriendlyError.details].
FriendlyError explainError(Object error, {String during = 'do that'}) {
  final raw = _trim(error.toString());
  final message = _message(error, during);
  return FriendlyError(message ?? 'Something went wrong while trying to $during. Please try again.', raw);
}

const _noConnection = "Couldn't reach the server. Check your internet connection and try again.";

String? _message(Object error, String during) {
  if (error is FirebaseException) return _firebase(error.code, during);
  if (error is TimeoutException) return 'The server took too long to answer. Try again in a moment.';
  if (error is PlatformException) return _platform(error.code, error.message);
  if (error is UnsupportedError) return "That isn't available here.";

  // Network failures arrive as different classes on each platform; match by name
  // so this works the same on the phone, the Mac app and the website.
  final type = error.runtimeType.toString();
  if (type.contains('SocketException') || type.contains('ClientException') || type.contains('HandshakeException')) {
    return _noConnection;
  }
  // Sign-in errors from the Google plugin carry a code in their description.
  final text = error.toString();
  if (text.contains('GoogleSignInExceptionCode.canceled')) return 'Sign-in was cancelled.';
  if (text.contains('GoogleSignInExceptionCode')) return "Google sign-in didn't work. Try again.";
  return null;
}

String? _firebase(String code, String during) {
  switch (code) {
    case 'unauthorized':
    case 'permission-denied':
    case 'unauthenticated':
      return "This account isn't allowed to $during. Sign in with an account on the allowed list.";
    case 'canceled':
    case 'cancelled':
      return 'Cancelled.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return 'The sign-in window was closed before it finished. Try again.';
    case 'popup-blocked':
      return 'Your browser blocked the sign-in window. Allow pop-ups for this site and try again.';
    case 'network-request-failed':
    case 'retry-limit-exceeded':
    case 'unavailable':
      return _noConnection;
    case 'quota-exceeded':
      return 'The storage limit was reached, so nothing more can be uploaded right now.';
    case 'object-not-found':
      return "That file couldn't be found online.";
    case 'invalid-checksum':
    case 'server-file-wrong-size':
      return 'The upload was damaged on the way. Try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes and try again.';
  }
  return null;
}

String? _platform(String code, String? message) {
  final text = '$code ${message ?? ''}'.toLowerCase();
  if (text.contains('cancel')) return 'Cancelled.';
  if (text.contains('network')) return _noConnection;
  if (text.contains('permission')) return 'Permission was not granted. Allow it in your settings and try again.';
  return null;
}

String _trim(String text) => text.length <= 400 ? text : '${text.substring(0, 400)}…';
