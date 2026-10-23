import 'package:flutter/material.dart';

/// Record / stop button for the website's Record tab, with the elapsed time.
class WebRecordControls extends StatelessWidget {
  final bool isRecording;
  final Duration elapsed;
  final bool hasTake;
  final bool enabled;
  final VoidCallback onToggle;

  const WebRecordControls({
    super.key,
    required this.isRecording,
    required this.elapsed,
    required this.hasTake,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRecording
              ? 'Recording from your microphone.'
              : 'Records through your computer\'s microphone. Play the music near it.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
            color: theme.colorScheme.error,
          ),
          label: Text(_label()),
        ),
      ],
    );
  }

  String _label() {
    if (isRecording) {
      return 'Stop (${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')})';
    }
    return hasTake ? 'Record again' : 'Start recording';
  }
}
