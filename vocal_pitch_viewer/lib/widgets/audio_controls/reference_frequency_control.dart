import 'package:flutter/material.dart';

/// Compact reference frequency (A4) control widget.
///
/// Stepper + text field for tuning A4 in the 400–480 Hz range, with a
/// reset button that snaps back to 440 Hz.
class ReferenceFrequencyControl extends StatefulWidget {
  final double frequency;
  final ValueChanged<double> onChanged;

  const ReferenceFrequencyControl({
    super.key,
    required this.frequency,
    required this.onChanged,
  });

  @override
  State<ReferenceFrequencyControl> createState() =>
      _ReferenceFrequencyControlState();
}

class _ReferenceFrequencyControlState extends State<ReferenceFrequencyControl> {
  static const double _minHz = 400.0;
  static const double _maxHz = 480.0;
  static const double _defaultHz = 440.0;

  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.frequency.toStringAsFixed(1));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(ReferenceFrequencyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frequency != oldWidget.frequency && !_focusNode.hasFocus) {
      _controller.text = widget.frequency.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _increment() => widget.onChanged((widget.frequency + 1.0).clamp(_minHz, _maxHz));
  void _decrement() => widget.onChanged((widget.frequency - 1.0).clamp(_minHz, _maxHz));
  void _reset() => widget.onChanged(_defaultHz);

  void _submitValue() {
    final value = double.tryParse(_controller.text);
    if (value != null) {
      widget.onChanged(value.clamp(_minHz, _maxHz));
    } else {
      _controller.text = widget.frequency.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A4:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 16),
          onPressed: _decrement,
          tooltip: 'Decrease frequency',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        _FrequencyField(
          controller: _controller,
          focusNode: _focusNode,
          colorScheme: colorScheme,
          theme: theme,
          onSubmit: _submitValue,
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 16),
          onPressed: _increment,
          tooltip: 'Increase frequency',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 2),
        Text(
          'Hz',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          onPressed: _reset,
          tooltip: 'Reset to 440 Hz',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// Numeric text field for entering A4 frequency directly.
class _FrequencyField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onSubmit;

  const _FrequencyField({
    required this.controller,
    required this.focusNode,
    required this.colorScheme,
    required this.theme,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => onSubmit(),
        onEditingComplete: onSubmit,
      ),
    );
  }
}
