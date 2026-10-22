import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/audio_content_type.dart';
import 'queue_status.dart';

/// Web client id of the Firebase project (from google-services.json); the
/// in-app Google sheet needs it to mint an ID token Firebase Auth accepts.
/// Not a secret.
const _serverClientId =
    '863000613215-u31ghed12gcrsf3n4on2vs2f83gl8lh2.apps.googleusercontent.com';

/// Submits songs to the processing queue in Firebase Storage: the audio goes to
/// `uploads/<id>/<file>`, then `queue/<id>.json` tells a worker to pick it up.
/// Storage rules only let allow-listed Google accounts write either path.
class CloudUpload {
  static const bool isSupported = true;

  static bool _ready = false;

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

  String _newRequestId() => 'r${DateTime.now().millisecondsSinceEpoch}'
      '${Random().nextInt(0xFFFF).toRadixString(16)}';

  Future<void> _writeQueueEntry(String id, Map<String, Object?> fields) {
    final entry = jsonEncode({
      ...fields,
      'status': 'queued',
      'created_at': DateTime.now().millisecondsSinceEpoch / 1000,
    });
    return FirebaseStorage.instance
        .ref('queue/$id.json')
        .putString(entry, metadata: SettableMetadata(contentType: 'application/json'));
  }

  /// Uploads [bytes] and queues them. Returns the request id to poll.
  Future<String> submit({
    required Uint8List bytes,
    required String fileName,
    required AudioContentType audioType,
    void Function(double fraction)? onProgress,
  }) async {
    await _init();
    final id = _newRequestId();
    final storage = FirebaseStorage.instance;

    final task = storage.ref('uploads/$id/$fileName').putData(bytes);
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    await task;

    await _writeQueueEntry(id, {
      'id': id,
      'filename': fileName,
      'audio_type': audioType.apiValue,
    });
    return id;
  }

  /// Queues a pasted link; the worker downloads the audio itself.
  Future<String> submitUrl({
    required String url,
    required AudioContentType audioType,
  }) async {
    await _init();
    final id = _newRequestId();
    await _writeQueueEntry(id, {
      'id': id,
      'filename': url,
      'source_url': url,
      'audio_type': audioType.apiValue,
    });
    return id;
  }

  /// Current worker-reported status, or null if the entry can't be read yet.
  Future<QueueStatus?> status(String requestId) async {
    await _init();
    try {
      final data = await FirebaseStorage.instance.ref('queue/$requestId.json').getData();
      if (data == null) return null;
      return QueueStatus.fromJson(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
    } on FirebaseException {
      return null;
    }
  }
}
