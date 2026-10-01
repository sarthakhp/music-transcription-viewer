import 'package:flutter/material.dart';

/// Shows [builder]'s content in a modal bottom sheet with the app's standard
/// handle, title and safe-area padding.
Future<void> showControlSheet({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            builder(sheetContext),
          ],
        ),
      ),
    ),
  );
}

/// Large circular +/- stepper around a [value] label, sized for thumbs.
class BigStepper extends StatelessWidget {
  final String value;
  final String? caption;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decrementLabel;
  final String incrementLabel;

  const BigStepper({
    super.key,
    required this.value,
    this.caption,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementLabel,
    required this.incrementLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
          iconSize: 28,
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          tooltip: decrementLabel,
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_rounded),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        IconButton.filledTonal(
          iconSize: 28,
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          tooltip: incrementLabel,
          onPressed: onIncrement,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
