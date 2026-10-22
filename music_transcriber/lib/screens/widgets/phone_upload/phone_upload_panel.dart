import 'package:flutter/material.dart';
import '../../../models/audio_content_type.dart';
import '../../../services/cloud_upload/cloud_upload.dart';
import '../../../services/phone_audio/audio_draft.dart';
import '../../../services/phone_audio/phone_file_picker.dart';
import '../../../services/phone_audio/phone_recording.dart';
import '../../../services/phone_audio/system_audio_recorder.dart';
import 'account_bar.dart';
import 'clip_review.dart';
import 'record_controls.dart';
import 'submission_list.dart';
import 'submission_tracker.dart';

enum _Source { file, record, link }

/// Android-only card: sign in with Google, then add a song from a file, a
/// recording (microphone or other apps' audio) or a link. It is queued for
/// processing and followed to completion. [onLibraryChanged] fires when a
/// submission finishes so the song list can refresh.
class PhoneUploadPanel extends StatefulWidget {
  final VoidCallback onLibraryChanged;
  const PhoneUploadPanel({super.key, required this.onLibraryChanged});

  @override
  State<PhoneUploadPanel> createState() => _PhoneUploadPanelState();
}

class _PhoneUploadPanelState extends State<PhoneUploadPanel> {
  final _cloud = CloudUpload();
  late final SubmissionTracker _tracker;
  final PhoneRecording _recording = PhoneRecording();
  final AudioDraft _draft = AudioDraft();
  final TextEditingController _url = TextEditingController();

  String? _email;
  _Source _source = _Source.file;
  RecordSource _recordSource = RecordSource.microphone;
  AudioContentType _audioType = AudioContentType.mixed;
  bool _phoneAudioSupported = false;
  bool _busy = false;
  double? _uploadFraction;
  String? _error;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _tracker = SubmissionTracker(_cloud, onJobFinished: widget.onLibraryChanged)
      ..addListener(_rebuild);
    _recording.addListener(_rebuild);
    _draft.addListener(_rebuild);
    _url.addListener(_rebuild);
    SystemAudioRecorder.isSupported().then((v) {
      if (mounted) setState(() => _phoneAudioSupported = v);
    });
    _restoreSession();
  }

  @override
  void dispose() {
    _tracker.dispose();
    _recording.dispose();
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
      if (mounted) setState(() => _error = 'Sign-in setup failed: $e');
    }
  }

  // --- Account ---------------------------------------------------------------

  Future<void> _signIn() => _guarded('Sign-in failed', () async {
        final email = await _cloud.signIn();
        if (mounted) setState(() => _email = email);
      });

  Future<void> _signOut() async {
    await _cloud.signOut();
    if (mounted) setState(() => _email = null);
  }

  // --- Sources ---------------------------------------------------------------

  Future<void> _pickFile() async {
    final picked = await pickAudioFile();
    if (picked == null || !mounted) return;
    setState(() => _error = null);
    if (!await _draft.replaceWith(picked) && mounted) {
      setState(() => _error = 'That file could not be read as audio.');
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) return _finishRecording();
    // A new take replaces the previous one: delete it before recording starts.
    await _draft.clear();
    setState(() {
      _error = null;
      _warning = null;
    });
    final started = await _recording.start(_recordSource);
    if (!started && mounted) {
      setState(() => _error = 'Recording was not allowed. Check the permission prompt.');
    }
  }

  Future<void> _finishRecording() async {
    final done = await _recording.stop();
    if (!mounted) return;
    if (done == null) {
      setState(() => _error = 'Nothing was recorded.');
      return;
    }
    setState(() => _warning = done.warning);
    if (!await _draft.replaceWith(done.audio) && mounted) {
      setState(() => _error = 'The recording could not be read.');
    }
  }

  // --- Submitting ------------------------------------------------------------

  bool get _canSubmit {
    if (_busy || _recording.isRecording) return false;
    return _source == _Source.link ? _url.text.trim().isNotEmpty : _draft.hasAudio && _draft.duration > 0;
  }

  Future<void> _submitSelected() =>
      _source == _Source.link ? _submitLink() : _submitFile();

  Future<void> _submitFile() async {
    final audio = _draft.audio;
    if (audio == null) return;
    final trimmed = _draft.isTrimmed;
    await _submit(audio.name, () => _cloud.submit(
          path: audio.path,
          fileName: audio.name,
          audioType: _audioType,
          trimStart: trimmed ? _draft.trimStart : null,
          trimEnd: trimmed ? _draft.trimEnd : null,
          onProgress: (f) => setState(() => _uploadFraction = f),
        ));
    await _draft.clear(); // uploaded: drop the local copy
  }

  Future<void> _submitLink() async {
    final url = _url.text.trim();
    if (!url.startsWith('http') || Uri.tryParse(url)?.hasAuthority != true) {
      setState(() => _error = 'Paste a full link starting with http');
      return;
    }
    await _submit(url, () => _cloud.submitUrl(url: url, audioType: _audioType));
    _url.clear();
  }

  /// Runs [send] (which returns the new request id) and starts tracking it.
  Future<void> _submit(String label, Future<String> Function() send) {
    return _guarded('Upload failed', () async {
      setState(() {
        _warning = null;
        _uploadFraction = 0;
      });
      await _tracker.add(await send(), label);
    }, onDone: () => _uploadFraction = null);
  }

  /// Shows a busy state around [action] and turns failures into [failure] text.
  Future<void> _guarded(String failure, Future<void> Function() action,
      {VoidCallback? onDone}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$failure: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          onDone?.call();
        });
      }
    }
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a song from this phone', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_email == null) _signInButton() else ..._form(),
            if (_error != null) _message(_error!, theme.colorScheme.error),
            if (_warning != null) _message(_warning!, theme.colorScheme.tertiary),
            if (_tracker.items.isNotEmpty) ...[
              const Divider(height: 28),
              SubmissionList(items: _tracker.items),
            ],
          ],
        ),
      ),
    );
  }

  Widget _signInButton() => FilledButton.icon(
        onPressed: _busy ? null : _signIn,
        icon: const Icon(Icons.login_rounded),
        label: const Text('Sign in with Google'),
      );

  List<Widget> _form() => [
        AccountBar(email: _email!, enabled: !_busy, onSignOut: _signOut),
        const SizedBox(height: 8),
        _sourceSelector(),
        const SizedBox(height: 12),
        _sourceBody(),
        const SizedBox(height: 12),
        _typeChips(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _canSubmit ? _submitSelected : null,
          icon: Icon(_source == _Source.link ? Icons.link_rounded : Icons.cloud_upload_rounded),
          label: Text(_source == _Source.link ? 'Transcribe link' : 'Upload and transcribe'),
        ),
        if (_uploadFraction != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _source == _Source.link ? null : _uploadFraction),
        ],
      ];

  Widget _sourceSelector() => SegmentedButton<_Source>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _Source.file, icon: Icon(Icons.audio_file_rounded), label: Text('File')),
          ButtonSegment(value: _Source.record, icon: Icon(Icons.mic_rounded), label: Text('Record')),
          ButtonSegment(value: _Source.link, icon: Icon(Icons.link_rounded), label: Text('Link')),
        ],
        selected: {_source},
        onSelectionChanged:
            (_busy || _recording.isRecording) ? null : (v) => setState(() => _source = v.first),
      );

  Widget _sourceBody() {
    switch (_source) {
      case _Source.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_draft.hasAudio ? 'Choose a different file' : 'Choose an audio file'),
            ),
            _review(),
          ],
        );
      case _Source.record:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordControls(
              recording: _recording,
              source: _recordSource,
              phoneAudioSupported: _phoneAudioSupported,
              enabled: !_busy,
              hasTake: _draft.hasAudio,
              onSourceChanged: (s) => setState(() => _recordSource = s),
              onToggle: _toggleRecording,
            ),
            _review(),
          ],
        );
      case _Source.link:
        return TextField(
          controller: _url,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Link (YouTube or other)',
            border: OutlineInputBorder(),
          ),
        );
    }
  }

  /// The clip under review, with spacing only when there is one to show.
  Widget _review() {
    if (!_draft.hasAudio || _recording.isRecording) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ClipReview(draft: _draft),
    );
  }

  Widget _typeChips() => Wrap(
        spacing: 8,
        children: [
          for (final type in AudioContentType.values)
            ChoiceChip(
              label: Text(type.label),
              selected: _audioType == type,
              onSelected: _busy ? null : (_) => setState(() => _audioType = type),
            ),
        ],
      );

  Widget _message(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, style: TextStyle(color: color)),
      );
}
