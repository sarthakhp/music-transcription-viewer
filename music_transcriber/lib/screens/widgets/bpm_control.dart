import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tempo readout that opens the BPM editor when tapped.
///
/// Tempo detection is often off by half or double, so the number is editable:
/// type it, halve/double it, or tap it in. An edited value shows a dot.
class BpmStat extends StatelessWidget {
  final double? bpm;
  final double? detectedBpm;
  final ValueChanged<double?> onChanged;
  final TextStyle? style;
  final Color color;

  const BpmStat({
    super.key,
    required this.bpm,
    required this.detectedBpm,
    required this.onChanged,
    required this.color,
    this.style,
  });

  bool get _edited => bpm != null && detectedBpm != null && (bpm! - detectedBpm!).abs() > 0.05;

  static String format(double bpm) =>
      bpm == bpm.roundToDouble() ? bpm.toStringAsFixed(0) : bpm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final value = bpm;
    return Tooltip(
      message: 'Edit tempo',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final result = await showDialog<_BpmResult>(
            context: context,
            builder: (_) => _BpmDialog(current: value, detected: detectedBpm),
          );
          if (result != null) onChanged(result.bpm);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(value == null ? 'Set BPM' : '${format(value)} BPM',
                  style: style?.copyWith(color: color)),
              if (_edited) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.edit_outlined, size: 12, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the dialog returns: the new override, or null to go back to detected.
class _BpmResult {
  final double? bpm;
  const _BpmResult(this.bpm);
}

/// Collects tap-tempo presses; the tempo is the average of recent intervals.
@visibleForTesting
class TapTempo {
  static const _resetAfter = Duration(seconds: 2);
  static const _window = 8;

  final List<DateTime> _taps = [];

  /// Registers a tap and returns the tempo once there are at least two taps.
  double? tap(DateTime now) {
    if (_taps.isNotEmpty && now.difference(_taps.last) > _resetAfter) _taps.clear();
    _taps.add(now);
    if (_taps.length > _window) _taps.removeAt(0);
    if (_taps.length < 2) return null;
    final span = _taps.last.difference(_taps.first).inMicroseconds / 1e6;
    return 60.0 * (_taps.length - 1) / span;
  }
}

class _BpmDialog extends StatefulWidget {
  final double? current;
  final double? detected;
  const _BpmDialog({required this.current, required this.detected});

  @override
  State<_BpmDialog> createState() => _BpmDialogState();
}

class _BpmDialogState extends State<_BpmDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current == null ? '' : BpmStat.format(widget.current!),
  );
  final TapTempo _tapTempo = TapTempo();

  double? get _value => double.tryParse(_controller.text.trim());
  bool get _valid => _value != null && _value! >= 20 && _value! <= 400;

  void _set(double bpm) {
    final clamped = bpm.clamp(20.0, 400.0).toDouble();
    setState(() => _controller.text = clamped.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''));
  }

  void _scale(double factor) {
    final v = _value ?? widget.detected;
    if (v != null) _set(v * factor);
  }

  void _tap() {
    final bpm = _tapTempo.tap(DateTime.now());
    if (bpm != null) _set(bpm);
  }

  void _submit() {
    if (_valid) Navigator.pop(context, _BpmResult(_value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detected = widget.detected;
    return AlertDialog(
      title: const Text('Tempo'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'BPM',
                errorText: _controller.text.isNotEmpty && !_valid ? 'Enter 20 – 400' : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => _scale(0.5), child: const Text('½×')),
                OutlinedButton(onPressed: () => _scale(2), child: const Text('2×')),
                FilledButton.tonalIcon(
                  onPressed: _tap,
                  icon: const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('Tap tempo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              detected == null
                  ? 'No tempo was detected for this song.'
                  : 'Detected: ${BpmStat.format(detected)} BPM. Detection is sometimes half or double the real tempo; use ½× / 2× or tap along to fix it.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        if (detected != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _BpmResult(null)),
            child: const Text('Use detected'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _valid ? _submit : null, child: const Text('Set')),
      ],
    );
  }
}
