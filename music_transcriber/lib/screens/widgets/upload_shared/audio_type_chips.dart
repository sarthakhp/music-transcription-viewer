import 'package:flutter/material.dart';
import '../../../models/audio_content_type.dart';

/// Song / Voice only / Music only: what the recording contains, which decides
/// how it is processed.
class AudioTypeChips extends StatelessWidget {
  final AudioContentType selected;
  final bool enabled;
  final ValueChanged<AudioContentType> onChanged;

  const AudioTypeChips({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final type in AudioContentType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: selected == type,
            onSelected: enabled ? (_) => onChanged(type) : null,
          ),
      ],
    );
  }
}
