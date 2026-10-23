import 'package:flutter/material.dart';

enum UploadSource { file, record, link }

/// The File / Record / Link switch at the top of the upload form.
class SourceSelector extends StatelessWidget {
  final UploadSource selected;
  final bool enabled;
  final ValueChanged<UploadSource> onChanged;

  const SourceSelector({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UploadSource>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: UploadSource.file, icon: Icon(Icons.audio_file_rounded), label: Text('File')),
        ButtonSegment(value: UploadSource.record, icon: Icon(Icons.mic_rounded), label: Text('Record')),
        ButtonSegment(value: UploadSource.link, icon: Icon(Icons.link_rounded), label: Text('Link')),
      ],
      selected: {selected},
      onSelectionChanged: enabled ? (values) => onChanged(values.first) : null,
    );
  }
}
