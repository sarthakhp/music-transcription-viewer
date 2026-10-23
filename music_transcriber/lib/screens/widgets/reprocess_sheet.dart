import 'package:flutter/material.dart';
import '../../models/audio_content_type.dart';
import '../../models/job.dart';
import 'upload_shared/audio_type_chips.dart';
import 'upload_shared/instrument_picker.dart';

/// What the person chose to process a song again with.
class ReprocessChoice {
  final AudioContentType audioType;
  final List<String> instruments;
  const ReprocessChoice(this.audioType, this.instruments);
}

/// Asks how to process [job] again. Starts from the settings it was made with.
/// Returns null when dismissed.
Future<ReprocessChoice?> showReprocessSheet(BuildContext context, JobListItem job) {
  return showModalBottomSheet<ReprocessChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReprocessSheet(job: job),
  );
}

class ReprocessSheet extends StatefulWidget {
  final JobListItem job;
  const ReprocessSheet({super.key, required this.job});

  @override
  State<ReprocessSheet> createState() => _ReprocessSheetState();
}

class _ReprocessSheetState extends State<ReprocessSheet> {
  late AudioContentType _type = widget.job.audioType;
  late Set<String> _instruments = {...widget.job.instruments};

  bool get _usesInstruments => _type != AudioContentType.vocals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Process again', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '"${widget.job.displayName}" stays as it is. This makes a new song from the same audio.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('What is in it?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            AudioTypeChips(selected: _type, enabled: true, onChanged: (t) => setState(() => _type = t)),
            const SizedBox(height: 4),
            Text(_type.description, style: theme.textTheme.bodySmall),
            if (_usesInstruments) ...[
              const SizedBox(height: 12),
              InstrumentPicker(
                selected: _instruments,
                enabled: true,
                onChanged: (s) => setState(() => _instruments = s),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Process again'),
                  onPressed: () => Navigator.pop(
                    context,
                    ReprocessChoice(_type, _usesInstruments ? _instruments.toList() : const []),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
