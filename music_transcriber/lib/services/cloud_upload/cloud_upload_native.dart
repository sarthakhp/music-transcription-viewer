import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/audio_content_type.dart';
import 'job_notifications.dart';
import 'queue_protocol.dart';
import 'queue_status.dart';

/// Web client id of the Firebase project (from google-services.json); the
/// in-app Google sheet needs it to mint an ID token Firebase Auth accepts.
/// Not a secret.
const _serverClientId =
    '863000613215-u31ghed12gcrsf3n4on2vs2f83gl8lh2.apps.googleusercontent.com';

/// Submits songs to the processing queue in Firebase Storage (Android).
/// Storage rules only let allow-listed Google accounts write either path.
class CloudUpload {
  static bool get isSupported => true;

  static bool _ready = false;
  final JobNotifications _notifications = JobNotifications();

  Future<void> _init() async {
    if (_ready) return;
    await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _ready = true;
  }

  Future<String?> signedInEmail() async {
    await _init();
    return FirebaseAuth.instance.currentUser?.email;
  }

  /// Google sign-in: the in-app account sheet first. If that fails at once
  /// (Google hasn't activated this app's signing registration yet), fall back
  /// to Firebase's browser flow. A failure after the user spent time on the
  /// sheet is a real cancel and is rethrown.
  Future<String> signIn() async {
    await _init();
    final started = DateTime.now();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final result = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
      return result.user?.email ?? account.email;
    } on GoogleSignInException {
      if (DateTime.now().difference(started) > const Duration(seconds: 2)) rethrow;
      final result = await FirebaseAuth.instance.signInWithProvider(
        GoogleAuthProvider()..addScope('email'),
      );
      return result.user?.email ?? '';
    }
  }

  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// Streams the file at [path] to storage and queues it, optionally cut to
  /// [trimStart]..[trimEnd] seconds by the worker. Returns the request id.
  Future<String> submit({
    required String path,
    required String fileName,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    List<String> instruments = const [],
    void Function(double fraction)? onProgress,
  }) async {
    await _init();
    final id = newRequestId();
    final task = FirebaseStorage.instance.ref(uploadPath(id, fileName)).putFile(File(path));
    await _track(task, onProgress);
    await _writeEntry(id, fileName, audioType, trimStart: trimStart, trimEnd: trimEnd, instruments: instruments);
    return id;
  }

  /// Same as [submit] for audio already in memory.
  Future<String> submitBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    List<String> instruments = const [],
    void Function(double fraction)? onProgress,
  }) async {
    await _init();
    final id = newRequestId();
    final task = FirebaseStorage.instance
        .ref(uploadPath(id, fileName))
        .putData(bytes, SettableMetadata(contentType: contentType));
    await _track(task, onProgress);
    await _writeEntry(id, fileName, audioType, trimStart: trimStart, trimEnd: trimEnd, instruments: instruments);
    return id;
  }

  /// Queues a pasted link; the worker downloads the audio itself.
  Future<String> submitUrl({
    required String url,
    required AudioContentType audioType,
    List<String> instruments = const [],
  }) async {
    await _init();
    final id = newRequestId();
    await _writeEntry(id, url, audioType, sourceUrl: url, instruments: instruments);
    return id;
  }

  /// Asks for an existing song to be processed again as a new song.
  Future<String> submitReprocess({
    required String sourceJobId,
    required String label,
    required AudioContentType audioType,
    List<String> instruments = const [],
  }) async {
    await _init();
    final id = newRequestId();
    await _writeEntry(id, label, audioType, reprocessOf: sourceJobId, instruments: instruments);
    return id;
  }

  /// Current worker-reported status, or null if the entry can't be read yet.
  Future<QueueStatus?> status(String requestId) async {
    await _init();
    try {
      final data = await FirebaseStorage.instance.ref(queuePath(requestId)).getData();
      if (data == null) return null;
      return QueueStatus.fromJson(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
    } on FirebaseException {
      return null;
    }
  }

  Future<void> _track(UploadTask task, void Function(double fraction)? onProgress) async {
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    await task;
  }

  Future<void> _writeEntry(
    String id,
    String filename,
    AudioContentType audioType, {
    double? trimStart,
    double? trimEnd,
    String? sourceUrl,
    String? reprocessOf,
    List<String> instruments = const [],
  }) async {
    final entry = queueEntryJson(
      id: id,
      filename: filename,
      audioType: audioType,
      trimStart: trimStart,
      trimEnd: trimEnd,
      sourceUrl: sourceUrl,
      reprocessOf: reprocessOf,
      instruments: instruments,
      notifyTopic: await _notifications.topic(),
    );
    await FirebaseStorage.instance
        .ref(queuePath(id))
        .putString(entry, metadata: SettableMetadata(contentType: 'application/json'));
  }
}
