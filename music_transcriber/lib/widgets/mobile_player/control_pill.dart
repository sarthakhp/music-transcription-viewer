import 'package:flutter/material.dart';

/// Tappable summary of one playback setting ("Speed / 1x"), at least 48dp
/// tall. Highlighted when the setting differs from its default.
class ControlPill extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;
  final String semanticsHint;

  const ControlPill({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.semanticsHint,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = isActive ? scheme.onPrimaryContainer : scheme.onSurface;

    return Semantics(
      button: true,
      label: '$label, $value',
      hint: semanticsHint,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isActive
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
