import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/audio_content_type.dart';
import '../../services/cloud_upload/cloud_upload.dart';
import '../../utils/web_file_picker.dart';

/// Android-only card: sign in with Google, pick a song, queue it for
/// processing, and follow its progress. [onLibraryChanged] fires when a
/// submission finishes so the library list can refresh.
class PhoneUploadPanel extends StatefulWidget {
  final VoidCallback onLibraryChanged;
  const PhoneUploadPanel({super.key, required this.onLibraryChanged});

  @override
  State<PhoneUploadPanel> createState() => _PhoneUploadPanelState();
}

class _PhoneUploadPanelState extends State<PhoneUploadPanel> {
  static const _prefsKey = 'phone_submissions'; // "<id>\t<filename>"
  static const _maxRemembered = 8;

  final _cloud = CloudUpload();
  String? _email;
  String? _error;
  bool _busy = false;
  double? _uploadFraction;
  WebFilePickerResult? _picked;
  AudioContentType _audioType = AudioContentType.mixed;
  final List<QueueStatus> _submissions = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final email = await _cloud.signedInEmail();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? const [];
      for (final entry in saved) {
        final parts = entry.split('\t');
        _submissions.add(QueueStatus(
          id: parts[0],
          fileName: parts.length > 1 ? parts[1] : '',
          status: 'queued',
        ));
      }
      if (mounted) setState(() => _email = email);
      _refreshStatuses();
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign-in setup failed: $e');
    }
  }

  Future<void> _remember() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      [for (final s in _submissions) '${s.id}\t${s.fileName}'],
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = await _cloud.signIn();
      if (mounted) setState(() => _email = email);
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final picked = await pickFileWeb(hint: 'audio');
    if (picked != null && mounted) setState(() => _picked = picked);
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _uploadFraction = 0;
    });
    try {
      final id = await _cloud.submit(
        bytes: picked.bytes,
        fileName: picked.name,
        audioType: _audioType,
        onProgress: (f) {
          if (mounted) setState(() => _uploadFraction = f);
        },
      );
      _submissions.insert(
        0,
        QueueStatus(id: id, fileName: picked.name, status: 'queued'),
      );
      if (_submissions.length > _maxRemembered) _submissions.removeLast();
      await _remember();
      if (mounted) setState(() => _picked = null);
      _refreshStatuses();
    } catch (e) {
      if (mounted) setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadFraction = null;
        });
      }
    }
  }

  Future<void> _refreshStatuses() async {
    var finishedNow = false;
    for (var i = 0; i < _submissions.length; i++) {
      final current = _submissions[i];
      if (!current.isActive) continue;
      final fresh = await _cloud.status(current.id);
      if (fresh == null || !mounted) continue;
      if (fresh.isDone) finishedNow = true;
      setState(() => _submissions[i] = fresh);
    }
    if (finishedNow) widget.onLibraryChanged();
    _poll?.cancel();
    if (mounted && _submissions.any((s) => s.isActive)) {
      _poll = Timer(const Duration(seconds: 6), _refreshStatuses);
    }
  }

  String _describe(QueueStatus s) {
    switch (s.status) {
      case 'done':
        return 'Done, in your library';
      case 'failed':
        return 'Failed${s.error == null ? '' : ': ${s.error}'}';
      case 'queued':
        return 'Waiting for a worker (your Mac needs to be on)';
      default:
        return '${s.stage ?? 'Starting'} · ${s.progress}%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a song from this phone', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_email == null)
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
              )
            else ...[
              Row(children: [
                Icon(Icons.verified_user_rounded, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_email!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await _cloud.signOut();
                          if (mounted) setState(() => _email = null);
                        },
                  child: const Text('Sign out'),
                ),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.audio_file_rounded),
                label: Text(_picked?.name ?? 'Choose an audio file'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in AudioContentType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _audioType == type,
                      onSelected: _busy ? null : (_) => setState(() => _audioType = type),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_busy || _picked == null) ? null : _upload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Upload and transcribe'),
              ),
              if (_uploadFraction != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _uploadFraction),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_submissions.isNotEmpty) ...[
              const Divider(height: 28),
              for (final s in _submissions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    s.isDone
                        ? Icons.check_circle_rounded
                        : s.isFailed
                            ? Icons.error_rounded
                            : Icons.hourglass_top_rounded,
                    color: s.isFailed ? theme.colorScheme.error : null,
                  ),
                  title: Text(s.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_describe(s)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
