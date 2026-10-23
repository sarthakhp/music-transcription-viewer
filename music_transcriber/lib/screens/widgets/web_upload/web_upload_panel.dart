import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/audio_content_type.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/clip/web_clip_draft.dart';
import '../../../services/cloud_upload/cloud_upload.dart';
import '../../../utils/audio_mime.dart';
import '../../../utils/web_file_picker.dart';
import '../upload_shared/audio_type_chips.dart';
import '../upload_shared/busy_guard.dart';
import '../upload_shared/clip_review.dart';
import '../upload_shared/link_field.dart';
import '../upload_shared/source_selector.dart';
import '../upload_shared/submission_tracker.dart';
import '../upload_shared/upload_card.dart';
import '../upload_shared/upload_submit.dart';
import 'web_record_controls.dart';

/// Website card: sign in with Google, then add a song from a file, a
/// microphone recording or a link. It goes to the same queue the phone uses, so
/// whichever worker is free (your Mac, or the cloud) picks it up.
/// [onLibraryChanged] fires when a submission finishes so the song list refreshes.
class WebUploadPanel extends StatefulWidget {
  final VoidCallback onLibraryChanged;
  const WebUploadPanel({super.key, required this.onLibraryChanged});

  @override
  State<WebUploadPanel> createState() => _WebUploadPanelState();
}

class _WebUploadPanelState extends State<WebUploadPanel> with BusyGuard {
  final _cloud = CloudUpload();
  late final SubmissionTracker _tracker;
  final WebClipDraft _draft = WebClipDraft();
  final AudioRecorderService _recorder = AudioRecorderService();
  final TextEditingController _url = TextEditingController();
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  String? _email;
  UploadSource _source = UploadSource.file;
  AudioContentType _audioType = AudioContentType.mixed;

  @override
  void initState() {
    super.initState();
    _tracker = SubmissionTracker(_cloud, onJobFinished: widget.onLibraryChanged)
      ..addListener(_rebuild);
    _draft.addListener(_rebuild);
    _url.addListener(_rebuild);
    _restoreSession();
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_recorder.isRecording) _recorder.cancel();
    _tracker.dispose();
    _draft.dispose();
    _url.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreSession() async {
    try {
      final email = await _cloud.signedInEmail();
      if (mounted) setState(() => _email = email);
      await _tracker.restore();
    } catch (e) {
      if (mounted) setState(() => error = 'Sign-in setup failed: $e');
    }
  }

  // --- Account ---------------------------------------------------------------

  Future<void> _signIn() => guarded('Sign-in failed', () async {
        final email = await _cloud.signIn();
        if (mounted) setState(() => _email = email);
      });

  Future<void> _signOut() async {
    await _cloud.signOut();
    if (mounted) setState(() => _email = null);
  }

  // --- Sources ---------------------------------------------------------------

  Future<void> _pickFile() async {
    final picked = await pickFileWeb(accept: 'audio/*,video/*,.mp3,.wav,.flac,.m4a,.ogg,.webm', hint: 'audio');
    if (picked == null || !mounted) return;
    setState(() => error = null);
    final readable = await _draft.load(picked.bytes, picked.name, audioMimeTypeFor(picked.name));
    if (!readable && mounted) setState(() => error = 'This browser could not read that file as audio.');
  }

  Future<void> _toggleRecording() async {
    if (_recorder.isRecording) return _finishRecording();
    _draft.clear(); // a new take replaces the previous one
    setState(() => error = null);
    try {
      await _recorder.start();
    } catch (_) {
      if (mounted) setState(() => error = 'The microphone was not allowed. Check the browser permission.');
      return;
    }
    _elapsed = Duration.zero;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      _rebuild();
    });
    _rebuild();
  }

  Future<void> _finishRecording() async {
    _clock?.cancel();
    final mime = _recorder.mimeType;
    final bytes = await _recorder.stop();
    if (!mounted) return;
    if (bytes.isEmpty) {
      setState(() => error = 'Nothing was recorded.');
      return;
    }
    final stamp = DateTime.now().toString().substring(0, 16).replaceAll(':', '.');
    final readable = await _draft.load(bytes, 'Recording $stamp.${extensionForMime(mime)}', mime.split(';').first);
    if (!readable && mounted) setState(() => error = 'The recording could not be read.');
  }

  // --- Submitting ------------------------------------------------------------

  bool get _canSubmit {
    if (busy || _recorder.isRecording) return false;
    return _source == UploadSource.link ? _url.text.trim().isNotEmpty : _draft.hasClip && _draft.duration > 0;
  }

  Future<void> _submitSelected() => _source == UploadSource.link ? _submitLink() : _submitClip();

  Future<void> _submitClip() async {
    final bytes = _draft.bytes, name = _draft.name;
    if (bytes == null || name == null) return;
    final trimmed = _draft.isTrimmed;
    await _submit(name, () => _cloud.submitBytes(
          bytes: bytes,
          fileName: name,
          contentType: _draft.mimeType,
          audioType: _audioType,
          trimStart: trimmed ? _draft.trimStart : null,
          trimEnd: trimmed ? _draft.trimEnd : null,
          onProgress: (f) => setState(() => uploadFraction = f),
        ));
    _draft.clear(); // uploaded: release the bytes
  }

  Future<void> _submitLink() async {
    final url = _url.text.trim();
    if (!url.startsWith('http') || Uri.tryParse(url)?.hasAuthority != true) {
      setState(() => error = 'Paste a full link starting with http');
      return;
    }
    await _submit(url, () => _cloud.submitUrl(url: url, audioType: _audioType));
    _url.clear();
  }

  Future<void> _submit(String label, Future<String> Function() send) {
    return guarded('Upload failed', () async {
      setState(() => uploadFraction = 0);
      await _tracker.add(await send(), label);
    }, onDone: () => uploadFraction = null);
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return UploadCard(
      title: 'Add a song',
      email: _email,
      busy: busy,
      onSignIn: _signIn,
      onSignOut: _signOut,
      form: [
        SourceSelector(
          selected: _source,
          enabled: !(busy || _recorder.isRecording),
          onChanged: (source) => setState(() => _source = source),
        ),
        const SizedBox(height: 12),
        _sourceBody(),
        const SizedBox(height: 12),
        AudioTypeChips(
          selected: _audioType,
          enabled: !busy,
          onChanged: (type) => setState(() => _audioType = type),
        ),
        const SizedBox(height: 12),
        UploadSubmit(
          source: _source,
          enabled: _canSubmit,
          fraction: uploadFraction,
          onPressed: _submitSelected,
        ),
      ],
      error: error,
      warning: null,
      submissions: _tracker.items,
    );
  }

  Widget _sourceBody() {
    switch (_source) {
      case UploadSource.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_draft.hasClip ? 'Choose a different file' : 'Choose an audio file'),
            ),
            _review(),
          ],
        );
      case UploadSource.record:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WebRecordControls(
              isRecording: _recorder.isRecording,
              elapsed: _elapsed,
              hasTake: _draft.hasClip,
              enabled: !busy,
              onToggle: _toggleRecording,
            ),
            _review(),
          ],
        );
      case UploadSource.link:
        return LinkField(controller: _url, enabled: !busy);
    }
  }

  /// The clip under review, with spacing only when there is one to show.
  Widget _review() {
    if (!_draft.hasClip || _recorder.isRecording) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ClipReview(draft: _draft),
    );
  }
}
