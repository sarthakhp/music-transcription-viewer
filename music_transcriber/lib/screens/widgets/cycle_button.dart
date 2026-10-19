import 'package:flutter/material.dart';
import '../../models/cycle_state.dart';

/// GarageBand-style cycle yellow.
const Color cycleColor = Color(0xFFF5C518);

/// App-bar button that switches the cycle (loop) on and off.
class CycleButton extends StatelessWidget {
  final CycleState cycle;
  final VoidCallback onPressed;

  const CycleButton({super.key, required this.cycle, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cycle,
      builder: (context, _) {
        final on = cycle.enabled;
        final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
        return IconButton(
          tooltip: on ? 'Cycle on (C)' : 'Cycle off (C)',
          onPressed: onPressed,
          icon: Icon(Icons.loop_rounded, color: on ? cycleColor : muted),
          style: on
              ? IconButton.styleFrom(backgroundColor: cycleColor.withValues(alpha: 0.16))
              : null,
        );
      },
    );
  }
}
