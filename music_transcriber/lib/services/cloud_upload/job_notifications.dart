import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets a worker tell this phone when a queued song finishes.
///
/// The phone subscribes to a private FCM topic with a random name, kept in
/// preferences, and includes it in every queue entry. Only someone who knows
/// the topic name could listen in, and it never leaves the queue entry.
class JobNotifications {
  static const _prefsKey = 'notify_topic';
  static bool _permissionAsked = false;

  /// The topic to put in a queue entry, or null if notifications can't be set
  /// up. Never throws: a notification problem must not stop an upload.
  Future<String?> topic() async {
    try {
      await _askPermissionOnce();
      final prefs = await SharedPreferences.getInstance();
      var topic = prefs.getString(_prefsKey);
      if (topic == null) {
        topic = _newTopic();
        await prefs.setString(_prefsKey, topic);
      }
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      return topic;
    } catch (e) {
      debugPrint('JobNotifications unavailable: $e');
      return null;
    }
  }

  Future<void> _askPermissionOnce() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    // Android 13+ asks the user; older versions grant it silently.
    await FirebaseMessaging.instance.requestPermission();
  }

  static String _newTopic() {
    final random = Random.secure();
    final hex = List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
    return 'n_$hex';
  }
}
