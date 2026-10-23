import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/friendly_error.dart';
import '../../../models/audio_content_type.dart';
import '../../../services/cloud_upload/cloud_upload.dart';
import '../../../services/cloud_upload/upload_queue.dart';
import '../../../services/phone_audio/audio_draft.dart';
import '../../../services/phone_audio/phone_file_picker.dart';
import '../../../services/phone_audio/phone_recording.dart';
import '../../../services/phone_audio/system_audio_recorder.dart';
import '../../../services/share_intake/share_intake.dart';
import '../../../services/share_intake/shared_item.dart';
import '../upload_shared/audio_type_chips.dart';
import '../upload_shared/busy_guard.dart';
import '../upload_shared/instrument_picker.dart';
import '../upload_shared/link_field.dart';
import '../upload_shared/upload_card.dart';
import '../upload_shared/upload_submit.dart';
import '../upload_shared/clip_review.dart';
import '../upload_shared/source_selector.dart';
import 'record_controls.dart';

/// Android-only card: sign in with Google, then add a song from a file, a
/// recording (microphone or other apps' audio) or a link. It is queued for
/// processing and followed to completion. [onLibraryChanged] fires when a
/// submission finishes so the song list can refresh.
class PhoneUploadPanel extends StatefulWidget {
  final VoidCallback onLibraryChanged;

  /// Opens a finished song (the same as tapping it in the song list).
  final void Function(String jobId) onOpenJob;

  /// A finished song's name in the song list, if it is there.
  final String? Function(String jobId) titleForJob;

  const PhoneUploadPanel({
    super.key,
    required this.onLibraryChanged,
    required this.onOpenJob,
    required this.titleForJob,
  });

  @override
  State<PhoneUploadPanel> createState() => _PhoneUploadPanelState();
}

class _PhoneUploadPanelState extends State<PhoneUploadPanel> with BusyGuard {
  final _cloud = UploadQueue.instance.cloud;
  final _tracker = UploadQueue.instance.tracker;
  StreamSubscription<void>? _finishedSub;
  StreamSubscription<SharedItem>? _shareSub;
  final PhoneRecording _recording = PhoneRecording();
  final AudioDraft _draft = AudioDraft();
  final TextEditingController _url = TextEditingController();

  String? _email;
  UploadSource _source = UploadSource.file;
  RecordSource _recordSource = RecordSource.microphone;
  AudioContentType _audioType = AudioContentType.mixed;
  Set<String> _instruments = {};
  bool _phoneAudioSupported = false;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_rebuild);
    _finishedSub = UploadQueue.instance.jobFinished.listen((_) => widget.onLibraryChanged());
    _recording.addListener(_rebuild);
    _draft.addListener(_rebuild);
    _url.addListener(_rebuild);
    SystemAudioRecorder.isSupported().then((v) {
      if (mounted) setState(() => _phoneAudioSupported = v);
    });
    _shareSub = ShareIntake.instance.items.listen(_useShared);
    final waiting = ShareIntake.instance.takePending();
    if (waiting != null) _useShared(waiting);
    _restoreSession();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _finishedSub?.cancel();
    _tracker.removeListener(_rebuild);
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
      await UploadQueue.instance.restore();
    } catch (e) {
      if (mounted) setState(() => error = explainError(e, during: 'check your sign-in').message);
    }
  }

  // --- Shared in from another app ----------------------------------------------

  /// Puts what another app shared into the right tab, ready to send. Works even
  /// before sign-in: the choice is kept and shown once the form appears.
  Future<void> _useShared(SharedItem item) async {
    switch (item) {
      case SharedLink(:final url):
        setState(() {
          _source = UploadSource.link;
          _url.text = url;
          error = null;
        });
      case SharedAudio(:final audio):
        setState(() {
          _source = UploadSource.file;
          error = null;
        });
        if (!await _draft.replaceWith(audio) && mounted) {
          setState(() => error = 'That file could not be read as audio.');
        }
    }
  }

  // --- Account ---------------------------------------------------------------

  Future<void> _signIn() => guarded('sign in', () async {
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
    setState(() => error = null);
    if (!await _draft.replaceWith(picked) && mounted) {
      setState(() => error = 'That file could not be read as audio.');
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) return _finishRecording();
    // A new take replaces the previous one: delete it before recording starts.
    await _draft.clear();
    setState(() {
      error = null;
      _warning = null;
    });
    final started = await _recording.start(_recordSource);
    if (!started && mounted) {
      setState(() => error = 'Recording was not allowed. Check the permission prompt.');
    }
  }

  Future<void> _finishRecording() async {
    final done = await _recording.stop();
    if (!mounted) return;
    if (done == null) {
      setState(() => error = 'Nothing was recorded.');
      return;
    }
    setState(() => _warning = done.warning);
    if (!await _draft.replaceWith(done.audio) && mounted) {
      setState(() => error = 'The recording could not be read.');
    }
  }

  // --- Submitting ------------------------------------------------------------

  /// Voice-only recordings have no instruments to look for.
  bool get _usesInstruments => _audioType != AudioContentType.vocals;
  List<String> get _chosenInstruments => _usesInstruments ? _instruments.toList() : const [];

  bool get _canSubmit {
    if (busy || _recording.isRecording) return false;
    return _source == UploadSource.link ? _url.text.trim().isNotEmpty : _draft.hasAudio && _draft.duration > 0;
  }

  Future<void> _submitSelected() =>
      _source == UploadSource.link ? _submitLink() : _submitFile();

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
          instruments: _chosenInstruments,
          onProgress: (f) => setState(() => uploadFraction = f),
        ));
    await _draft.clear(); // uploaded: drop the local copy
  }

  Future<void> _submitLink() async {
    final url = _url.text.trim();
    if (!url.startsWith('http') || Uri.tryParse(url)?.hasAuthority != true) {
      setState(() => error = 'Paste a full link starting with http');
      return;
    }
    await _submit(url, () => _cloud.submitUrl(url: url, audioType: _audioType, instruments: _chosenInstruments));
    _url.clear();
  }

  /// Runs [send] (which returns the new request id) and starts tracking it.
  Future<void> _submit(String label, Future<String> Function() send) {
    return guarded('upload this song', () async {
      setState(() {
        _warning = null;
        uploadFraction = 0;
      });
      await _tracker.add(await send(), label);
    }, onDone: () => uploadFraction = null);
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return UploadCard(
      title: 'Add a song from this phone',
      email: _email,
      busy: busy,
      onSignIn: _signIn,
      onSignOut: _signOut,
      form: _form(),
      error: error,
      warning: _warning,
      submissions: _tracker.items,
      onOpenJob: widget.onOpenJob,
      onDismissSubmission: _tracker.dismiss,
      titleForJob: widget.titleForJob,
    );
  }

  List<Widget> _form() => [
        _sourceSelector(),
        const SizedBox(height: 12),
        _sourceBody(),
        const SizedBox(height: 12),
        _typeChips(),
        if (_usesInstruments) ...[
          const SizedBox(height: 8),
          InstrumentPicker(
            selected: _instruments,
            enabled: !busy,
            onChanged: (chosen) => setState(() => _instruments = chosen),
          ),
        ],
        const SizedBox(height: 12),
        UploadSubmit(
          source: _source,
          enabled: _canSubmit,
          fraction: uploadFraction,
          onPressed: _submitSelected,
        ),
      ];

  Widget _sourceSelector() => SourceSelector(
        selected: _source,
        enabled: !(busy || _recording.isRecording),
        onChanged: (source) => setState(() => _source = source),
      );

  Widget _sourceBody() {
    switch (_source) {
      case UploadSource.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_draft.hasAudio ? 'Choose a different file' : 'Choose an audio file'),
            ),
            _review(),
          ],
        );
      case UploadSource.record:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordControls(
              recording: _recording,
              source: _recordSource,
              phoneAudioSupported: _phoneAudioSupported,
              enabled: !busy,
              hasTake: _draft.hasAudio,
              onSourceChanged: (s) => setState(() => _recordSource = s),
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
    if (!_draft.hasAudio || _recording.isRecording) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ClipReview(draft: _draft),
    );
  }

  Widget _typeChips() => AudioTypeChips(
        selected: _audioType,
        enabled: !busy,
        onChanged: (type) => setState(() => _audioType = type),
      );
}
