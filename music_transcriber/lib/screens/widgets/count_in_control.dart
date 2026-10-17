import 'package:flutter/material.dart';
import '../../services/count_in_service.dart';

/// App-bar button that picks how many clicks to count in before playback
/// (Off, 1, 2, 3 or 4). Sits next to the tanpura button.
class CountInButton extends StatelessWidget {
  final CountInService countIn;
  final ValueChanged<int> onBeatsChanged;

  const CountInButton({
    super.key,
    required this.countIn,
    required this.onBeatsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: countIn,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final beats = countIn.beats;
        final isOn = beats > 0;
        return PopupMenuButton<int>(
          tooltip: isOn
              ? 'Count-in: $beats click${beats == 1 ? '' : 's'} before playback'
              : 'Count-in before playback (off)',
          initialValue: beats,
          onSelected: onBeatsChanged,
          itemBuilder: (_) => [
            for (final option in const [0, 1, 2, 3, 4])
              CheckedPopupMenuItem<int>(
                value: option,
                checked: option == beats,
                child: Text(option == 0 ? 'Count-in off' : '$option click${option == 1 ? '' : 's'}'),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: isOn ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                if (isOn)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$beats',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Large beat number shown over the graph while a count-in is running.
class CountInOverlay extends StatelessWidget {
  final CountInService countIn;

  const CountInOverlay({super.key, required this.countIn});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<int?>(
        valueListenable: countIn.currentBeat,
        builder: (context, beat, _) {
          return Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: beat == null ? 0 : 1,
              child: Text(
                '${beat ?? ''}',
                style: TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
