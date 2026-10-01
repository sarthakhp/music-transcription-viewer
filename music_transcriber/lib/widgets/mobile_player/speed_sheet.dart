import 'package:flutter/material.dart';
import '../audio_controls/speed_control.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet with large playback-speed choices.
void showSpeedSheet({
  required BuildContext context,
  required double speed,
  required ValueChanged<double> onChanged,
  List<double> presets = const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
}) {
  showControlSheet(
    context: context,
    title: 'Playback speed',
    builder: (_) => _SpeedOptions(speed: speed, presets: presets, onChanged: onChanged),
  );
}

class _SpeedOptions extends StatefulWidget {
  final double speed;
  final List<double> presets;
  final ValueChanged<double> onChanged;

  const _SpeedOptions({required this.speed, required this.presets, required this.onChanged});

  @override
  State<_SpeedOptions> createState() => _SpeedOptionsState();
}

class _SpeedOptionsState extends State<_SpeedOptions> {
  late double _speed = widget.speed;

  void _select(double v) {
    setState(() => _speed = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final p in widget.presets)
          ChoiceChip(
            label: SizedBox(
              width: 56,
              height: 40,
              child: Center(child: Text(SpeedControl.format(p), style: const TextStyle(fontSize: 16))),
            ),
            selected: p == _speed,
            showCheckmark: false,
            onSelected: (_) => _select(p),
          ),
      ],
    );
  }
}
