import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/audio_content_type.dart';
import 'queue_protocol.dart';
import 'queue_status.dart';

/// Web API key of the Firebase web app, passed at build time
/// (--dart-define=FIREBASE_WEB_API_KEY=...). Without it the site stays
/// read-only: there is nothing to sign in against.
const _apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');

const _options = FirebaseOptions(
  apiKey: _apiKey,
  appId: '1:863000613215:web:8a9a52edbeb685512ce6ea',
  messagingSenderId: '863000613215',
  projectId: 'music-transcription-6702c',
  authDomain: 'music-transcription-6702c.firebaseapp.com',
  storageBucket: 'music-transcription-6702c.firebasestorage.app',
);

/// Submits songs to the same processing queue as the phone, from the hosted
/// website. Sign-in is a Google popup; Storage rules let only allow-listed
/// accounts write.
class CloudUpload {
  static bool get isSupported => _apiKey.isNotEmpty;

  static bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await Firebase.initializeApp(options: _options);
    _ready = true;
  }

  /// The signed-in account, if any. Firebase restores the session from the
  /// browser asynchronously, so wait for its first answer.
  Future<String?> signedInEmail() async {
    await _init();
    final user = await FirebaseAuth.instance.authStateChanges().first;
    return user?.email;
  }

  Future<String> signIn() async {
    await _init();
    final result = await FirebaseAuth.instance.signInWithPopup(
      GoogleAuthProvider()..addScope('email'),
    );
    return result.user?.email ?? '';
  }

  Future<void> signOut() async {
    await _init();
    await FirebaseAuth.instance.signOut();
  }

  Future<String> submit({
    required String path,
    required String fileName,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    void Function(double fraction)? onProgress,
  }) =>
      throw UnsupportedError('A browser has no file paths; use submitBytes');

  Future<String> submitBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    void Function(double fraction)? onProgress,
  }) async {
    await _init();
    final id = newRequestId();
    final task = FirebaseStorage.instance
        .ref(uploadPath(id, fileName))
        .putData(bytes, SettableMetadata(contentType: contentType));
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    await task;
    await _writeEntry(id, fileName, audioType, trimStart: trimStart, trimEnd: trimEnd);
    return id;
  }

  Future<String> submitUrl({
    required String url,
    required AudioContentType audioType,
  }) async {
    await _init();
    final id = newRequestId();
    await _writeEntry(id, url, audioType, sourceUrl: url);
    return id;
  }

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

  Future<void> _writeEntry(
    String id,
    String filename,
    AudioContentType audioType, {
    double? trimStart,
    double? trimEnd,
    String? sourceUrl,
  }) {
    final entry = queueEntryJson(
      id: id,
      filename: filename,
      audioType: audioType,
      trimStart: trimStart,
      trimEnd: trimEnd,
      sourceUrl: sourceUrl,
    );
    return FirebaseStorage.instance
        .ref(queuePath(id))
        .putString(entry, metadata: SettableMetadata(contentType: 'application/json'));
  }
}
