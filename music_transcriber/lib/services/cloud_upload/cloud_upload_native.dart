import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/audio_content_type.dart';
import 'queue_status.dart';

/// Web client id of the Firebase project (from google-services.json); Google
/// sign-in needs it to mint an ID token Firebase Auth accepts. Not a secret.
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

  Future<String> signIn() async {
    await _init();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final result = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return result.user?.email ?? account.email;
  }

  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// Uploads [bytes] and queues them. Returns the request id to poll.
  Future<String> submit({
    required Uint8List bytes,
    required String fileName,
    required AudioContentType audioType,
    void Function(double fraction)? onProgress,
  }) async {
    await _init();
    final id = 'r${DateTime.now().millisecondsSinceEpoch}'
        '${Random().nextInt(0xFFFF).toRadixString(16)}';
    final storage = FirebaseStorage.instance;

    final task = storage.ref('uploads/$id/$fileName').putData(bytes);
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    await task;

    final entry = jsonEncode({
      'id': id,
      'filename': fileName,
      'audio_type': audioType.apiValue,
      'status': 'queued',
      'created_at': DateTime.now().millisecondsSinceEpoch / 1000,
    });
    await storage
        .ref('queue/$id.json')
        .putString(entry, metadata: SettableMetadata(contentType: 'application/json'));
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
