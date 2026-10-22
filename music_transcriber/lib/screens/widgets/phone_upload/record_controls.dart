import 'package:flutter/material.dart';
import '../../../services/phone_audio/phone_recording.dart';

/// Source choice, hint and record/stop button for the Record tab. The hint
/// area has a fixed height so the button never moves when the source changes.
class RecordControls extends StatelessWidget {
  static const _hintHeight = 44.0;

  final PhoneRecording recording;
  final RecordSource source;
  final bool phoneAudioSupported;
  final bool enabled;
  final bool hasTake;
  final ValueChanged<RecordSource> onSourceChanged;
  final VoidCallback onToggle;

  const RecordControls({
    super.key,
    required this.recording,
    required this.source,
    required this.phoneAudioSupported,
    required this.enabled,
    required this.hasTake,
    required this.onSourceChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = recording.isRecording;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (phoneAudioSupported) _sourceChips(isRecording),
        SizedBox(
          height: _hintHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_hint(isRecording), style: theme.textTheme.bodySmall),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
            color: theme.colorScheme.error,
          ),
          label: Text(_buttonLabel(isRecording)),
        ),
      ],
    );
  }

  Widget _sourceChips(bool locked) {
    return Wrap(
      spacing: 8,
      children: [
        _chip(Icons.mic_rounded, 'Microphone', RecordSource.microphone, locked),
        _chip(Icons.phone_android_rounded, 'Phone audio', RecordSource.phoneAudio, locked),
      ],
    );
  }

  Widget _chip(IconData icon, String label, RecordSource value, bool locked) {
    final selected = source == value;
    return ChoiceChip(
      // The icon already carries the label; a tick would overlap it.
      showCheckmark: false,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: locked ? null : (_) => onSourceChanged(value),
    );
  }

  String _hint(bool isRecording) {
    if (isRecording) {
      return source == RecordSource.phoneAudio
          ? 'Recording phone audio. Switch to the other app and play.'
          : 'Recording from the microphone.';
    }
    return source == RecordSource.phoneAudio
        ? 'Records whatever another app plays. Start here, switch to that app and press play.'
        : 'Records through the microphone. Hold the phone near the sound.';
  }

  String _buttonLabel(bool isRecording) {
    if (isRecording) return 'Stop (${_clock(recording.elapsed)})';
    return hasTake ? 'Record again' : 'Start recording';
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
