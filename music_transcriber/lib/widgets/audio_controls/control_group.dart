import 'package:flutter/material.dart';

/// A small caption above a control, so every control in a bar shares one
/// vertical rhythm: caption, then a 40px body.
///
/// With [filled] (the default) the body is a rounded tinted well, used for
/// steppers and values. Pass `filled: false` for children that already draw
/// their own outline (segmented buttons, chips).
class ControlGroup extends StatelessWidget {
  static const double bodyHeight = 40;

  final String label;
  final Widget child;
  final bool filled;

  /// The setting differs from its default: the caption turns teal with a dot
  /// and the body gets a teal outline, so changed settings are visible at a glance.
  final bool modified;

  /// When set and [modified], a small reset button appears in the caption.
  /// It lives in the caption so the control itself never shifts under the cursor.
  final VoidCallback? onReset;

  const ControlGroup({
    super.key,
    required this.label,
    required this.child,
    this.filled = true,
    this.modified = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 2),
          child: SizedBox(
            height: 18,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed-size slot so the caption text never shifts when the dot appears.
              SizedBox(
                width: 11,
                child: modified
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration:
                              BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: modified ? scheme.primary : scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (modified && onReset != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: 'Reset $label',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onReset,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.refresh_rounded, size: 13, color: scheme.primary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
        Container(
          height: bodyHeight,
          padding: filled ? const EdgeInsets.symmetric(horizontal: 4) : null,
          decoration: filled
              ? BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: modified ? scheme.primary.withValues(alpha: 0.55) : Colors.transparent,
                  ),
                )
              : null,
          // widthFactor: 1 keeps the box as wide as its content (a plain
          // alignment would stretch it to the full available width).
          child: Align(widthFactor: 1, child: child),
        ),
      ],
    );
  }
}
