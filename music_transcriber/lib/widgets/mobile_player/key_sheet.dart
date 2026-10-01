import 'package:flutter/material.dart';
import 'sheet_scaffold.dart';

const int _minSemitones = -12;
const int _maxSemitones = 12;

String formatSemitones(int n) => n == 0 ? '0 st' : (n > 0 ? '+$n st' : '$n st');

/// Bottom sheet for transposing the audio key in semitones.
void showKeySheet({
  required BuildContext context,
  required int amount,
  required ValueChanged<int> onChanged,
}) {
  showControlSheet(
    context: context,
    title: 'Transpose key',
    builder: (_) => _KeyOptions(amount: amount, onChanged: onChanged),
  );
}

class _KeyOptions extends StatefulWidget {
  final int amount;
  final ValueChanged<int> onChanged;

  const _KeyOptions({required this.amount, required this.onChanged});

  @override
  State<_KeyOptions> createState() => _KeyOptionsState();
}

class _KeyOptionsState extends State<_KeyOptions> {
  late int _amount = widget.amount;

  void _set(int v) {
    final clamped = v.clamp(_minSemitones, _maxSemitones);
    if (clamped == _amount) return;
    setState(() => _amount = clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BigStepper(
          value: formatSemitones(_amount),
          caption: 'semitones',
          decrementLabel: 'Transpose down',
          incrementLabel: 'Transpose up',
          onDecrement: _amount > _minSemitones ? () => _set(_amount - 1) : null,
          onIncrement: _amount < _maxSemitones ? () => _set(_amount + 1) : null,
        ),
        Slider(
          value: _amount.toDouble(),
          min: _minSemitones.toDouble(),
          max: _maxSemitones.toDouble(),
          divisions: _maxSemitones - _minSemitones,
          label: formatSemitones(_amount),
          onChanged: (v) => _set(v.round()),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _amount == 0 ? null : () => _set(0),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
