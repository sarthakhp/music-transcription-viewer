import 'package:flutter/material.dart';

/// Compact transpose stepper (–12 to +12 semitones).
///
/// Displays the current transpose amount as "+N st" / "–N st" / "0 st".
/// Tapping the label switches to a numeric text field for direct entry.
class TransposeControl extends StatefulWidget {
  final int amount;
  final ValueChanged<int> onChanged;

  const TransposeControl({super.key, required this.amount, required this.onChanged});

  @override
  State<TransposeControl> createState() => _TransposeControlState();
}

class _TransposeControlState extends State<TransposeControl> {
  static const int _minSemitones = -12;
  static const int _maxSemitones = 12;

  bool _editing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _submit();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = widget.amount.toString();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value != null) {
      widget.onChanged(value.clamp(_minSemitones, _maxSemitones));
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = widget.amount != 0;
    final label = widget.amount == 0
        ? '0 st'
        : (widget.amount > 0 ? '+${widget.amount} st' : '${widget.amount} st');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Key',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 16),
              onPressed: widget.amount > _minSemitones
                  ? () => widget.onChanged(widget.amount - 1)
                  : null,
              tooltip: 'Transpose down',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            _TransposeLabel(
              isActive: isActive,
              editing: _editing,
              controller: _controller,
              focusNode: _focusNode,
              label: label,
              colorScheme: colorScheme,
              theme: theme,
              onTap: _startEditing,
              onSubmit: _submit,
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 16),
              onPressed: widget.amount < _maxSemitones
                  ? () => widget.onChanged(widget.amount + 1)
                  : null,
              tooltip: 'Transpose up',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: isActive
                  ? IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      onPressed: () => widget.onChanged(0),
                      tooltip: 'Reset transpose',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Editable transpose value label — TextField while editing, Text otherwise.
class _TransposeLabel extends StatelessWidget {
  final bool isActive;
  final bool editing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onSubmit;

  const _TransposeLabel({
    required this.isActive,
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 24,
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: editing
            ? TextField(
                controller: controller,
                focusNode: focusNode,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isActive ? colorScheme.onPrimaryContainer : null,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => onSubmit(),
              )
            : Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isActive ? colorScheme.onPrimaryContainer : null,
                ),
              ),
      ),
    );
  }
}
