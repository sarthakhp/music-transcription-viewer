import 'package:flutter/material.dart';
import '../../utils/music_utils.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet for note naming (Western / Sargam), the tonic ("Sa"), and the
/// reference tuning (A4).
void showNotationSheet({
  required BuildContext context,
  required bool sargamEnabled,
  required ValueChanged<bool> onSargamToggled,
  required int scaleRoot,
  required ValueChanged<int> onScaleRootChanged,
  required double referenceFrequency,
  required ValueChanged<double> onReferenceFrequencyChanged,
}) {
  showControlSheet(
    context: context,
    title: 'Notation & tuning',
    builder: (_) => _NotationOptions(
      sargamEnabled: sargamEnabled,
      onSargamToggled: onSargamToggled,
      scaleRoot: scaleRoot,
      onScaleRootChanged: onScaleRootChanged,
      referenceFrequency: referenceFrequency,
      onReferenceFrequencyChanged: onReferenceFrequencyChanged,
    ),
  );
}

class _NotationOptions extends StatefulWidget {
  final bool sargamEnabled;
  final ValueChanged<bool> onSargamToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;
  final double referenceFrequency;
  final ValueChanged<double> onReferenceFrequencyChanged;

  const _NotationOptions({
    required this.sargamEnabled,
    required this.onSargamToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
    required this.referenceFrequency,
    required this.onReferenceFrequencyChanged,
  });

  @override
  State<_NotationOptions> createState() => _NotationOptionsState();
}

class _NotationOptionsState extends State<_NotationOptions> {
  static const double _minHz = 400;
  static const double _maxHz = 480;
  static const double _defaultHz = 440;

  late bool _sargam = widget.sargamEnabled;
  late int _root = widget.scaleRoot;
  late double _hz = widget.referenceFrequency;

  void _setHz(double v) {
    final clamped = v.clamp(_minHz, _maxHz).toDouble();
    if (clamped == _hz) return;
    setState(() => _hz = clamped);
    widget.onReferenceFrequencyChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Western (C D E)')),
            ButtonSegment(value: true, label: Text('Sargam (Sa Re Ga)')),
          ],
          selected: {_sargam},
          showSelectedIcon: false,
          style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.fromHeight(48))),
          onSelectionChanged: (s) {
            setState(() => _sargam = s.first);
            widget.onSargamToggled(s.first);
          },
        ),
        const SizedBox(height: 20),
        Text(_sargam ? 'Sa (tonic) and tanpura pitch' : 'Root note and tanpura pitch',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 12; i++)
              ChoiceChip(
                label: SizedBox(width: 30, height: 32, child: Center(child: Text(noteNames[i]))),
                selected: i == _root,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _root = i);
                  widget.onScaleRootChanged(i);
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Reference pitch (A4)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        BigStepper(
          value: '${_hz.toStringAsFixed(1)} Hz',
          caption: 'standard is 440 Hz',
          decrementLabel: 'Lower reference pitch',
          incrementLabel: 'Raise reference pitch',
          onDecrement: _hz > _minHz ? () => _setHz(_hz - 1) : null,
          onIncrement: _hz < _maxHz ? () => _setHz(_hz + 1) : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          // Hidden (not removed) when already at the default, so the sheet
          // doesn't change height.
          child: Visibility(
            visible: _hz != _defaultHz,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: TextButton.icon(
              onPressed: () => _setHz(_defaultHz),
              icon: Icon(Icons.restart_alt_rounded, color: muted),
              label: const Text('Reset to 440 Hz'),
            ),
          ),
        ),
      ],
    );
  }
}
