import 'package:flutter/material.dart';
import '../../../services/phone_recording.dart';

/// Source choice, record/stop button and status line for the Record tab.
class RecordControls extends StatelessWidget {
  final PhoneRecording recording;
  final RecordSource source;
  final bool phoneAudioSupported;
  final bool enabled;
  final String? recordedName;
  final ValueChanged<RecordSource> onSourceChanged;
  final VoidCallback onToggle;

  const RecordControls({
    super.key,
    required this.recording,
    required this.source,
    required this.phoneAudioSupported,
    required this.enabled,
    required this.recordedName,
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
        if (source == RecordSource.phoneAudio && !isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Records whatever another app plays. Start here, switch to '
              'that app and press play.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
            color: theme.colorScheme.error,
          ),
          label: Text(_buttonLabel(isRecording)),
        ),
        if (recordedName != null && !isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Recorded: $recordedName', style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _sourceChips(bool locked) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          avatar: const Icon(Icons.mic_rounded, size: 18),
          label: const Text('Microphone'),
          selected: source == RecordSource.microphone,
          onSelected: locked ? null : (_) => onSourceChanged(RecordSource.microphone),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.phone_android_rounded, size: 18),
          label: const Text('Phone audio'),
          selected: source == RecordSource.phoneAudio,
          onSelected: locked ? null : (_) => onSourceChanged(RecordSource.phoneAudio),
        ),
      ],
    );
  }

  String _buttonLabel(bool isRecording) {
    if (isRecording) return 'Stop (${_clock(recording.elapsed)})';
    return recordedName == null ? 'Start recording' : 'Record again';
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
