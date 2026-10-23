import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/utils/friendly_error.dart';

class _FakeSocketException implements Exception {
  @override
  String toString() => 'SocketException: Failed host lookup';
}

void main() {
  FriendlyError explain(Object e) => explainError(e, during: 'upload this song');

  test('a permission problem says what to do', () {
    final f = explain(FirebaseException(plugin: 'storage', code: 'unauthorized', message: 'not allowed'));
    expect(f.message, "This account isn't allowed to upload this song. Sign in with an account on the allowed list.");
    expect(f.details, contains('unauthorized'));
  });

  test('network trouble is described the same way whatever threw it', () {
    const noConnection = "Couldn't reach the server. Check your internet connection and try again.";
    expect(explain(FirebaseException(plugin: 'storage', code: 'retry-limit-exceeded')).message, noConnection);
    expect(explain(_FakeSocketException()).message, noConnection);
    expect(explain(TimeoutException('x')).message, 'The server took too long to answer. Try again in a moment.');
  });

  test('closing or blocking the sign-in window is explained', () {
    expect(explain(FirebaseException(plugin: 'auth', code: 'popup-closed-by-user')).message, contains('closed'));
    expect(explain(FirebaseException(plugin: 'auth', code: 'popup-blocked')).message, contains('pop-ups'));
  });

  test('a cancelled sign-in is not reported as a failure', () {
    expect(explain(Exception('GoogleSignInException(code GoogleSignInExceptionCode.canceled, [16] Cancelled by user., null)')).message,
        'Sign-in was cancelled.');
    expect(explain(PlatformException(code: 'sign_in_canceled')).message, 'Cancelled.');
  });

  test('an unknown error still gets a plain sentence, with the raw text kept aside', () {
    final f = explain(StateError('weird internal thing'));
    expect(f.message, 'Something went wrong while trying to upload this song. Please try again.');
    expect(f.details, contains('weird internal thing'));
    expect(f.message, isNot(contains('StateError')));
  });

  test('very long technical text is shortened', () {
    expect(explain(StateError('x' * 2000)).details!.length, lessThan(450));
  });
}
