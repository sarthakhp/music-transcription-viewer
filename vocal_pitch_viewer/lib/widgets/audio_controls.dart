import 'package:flutter/material.dart';
import '../utils/music_utils.dart';

/// Audio playback controls widget
class AudioControls extends StatelessWidget {
  final bool isPlaying;
  final double currentTime;
  final double duration;
  final double referenceFrequency;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onReferenceFrequencyChange;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double viewWindowSize;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.referenceFrequency,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.onReferenceFrequencyChange,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.viewWindowSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek slider
          Row(
            children: [
              Text(
                formatTime(currentTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: currentTime.clamp(0, duration > 0 ? duration : 1),
                    min: 0,
                    max: duration > 0 ? duration : 1,
                    onChanged: duration > 0 ? onSeek : null,
                  ),
                ),
              ),
              Text(
                formatTime(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Playback controls
          Row(
            children: [
              // Zoom controls (left side)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom in button
                      IconButton(
                        icon: const Icon(Icons.zoom_in_rounded, size: 20),
                        onPressed: onZoomIn,
                        tooltip: 'Zoom In',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Zoom out button
                      IconButton(
                        icon: const Icon(Icons.zoom_out_rounded, size: 20),
                        onPressed: onZoomOut,
                        tooltip: 'Zoom Out',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Zoom level indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${viewWindowSize.toStringAsFixed(0)}s',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Stop button
              IconButton(
                icon: const Icon(Icons.stop_rounded),
                onPressed: onStop,
                tooltip: 'Stop',
              ),
              const SizedBox(width: 8),
              // Play/Pause button
              FilledButton.icon(
                onPressed: onPlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isPlaying ? 'Pause' : 'Play'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Skip forward/backward
              IconButton(
                icon: const Icon(Icons.replay_5_rounded),
                onPressed: () => onSeek((currentTime - 5).clamp(0, duration)),
                tooltip: 'Back 5s',
              ),
              IconButton(
                icon: const Icon(Icons.forward_5_rounded),
                onPressed: () => onSeek((currentTime + 5).clamp(0, duration)),
                tooltip: 'Forward 5s',
              ),
              const Spacer(),
              // Reference frequency control
              _ReferenceFrequencyControl(
                frequency: referenceFrequency,
                onChanged: onReferenceFrequencyChange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact reference frequency control widget
class _ReferenceFrequencyControl extends StatefulWidget {
  final double frequency;
  final ValueChanged<double> onChanged;

  const _ReferenceFrequencyControl({
    required this.frequency,
    required this.onChanged,
  });

  @override
  State<_ReferenceFrequencyControl> createState() => _ReferenceFrequencyControlState();
}

class _ReferenceFrequencyControlState extends State<_ReferenceFrequencyControl> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.frequency.toStringAsFixed(1));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_ReferenceFrequencyControl oldWidget) {
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

  void _increment() {
    final newValue = (widget.frequency + 1.0).clamp(400.0, 480.0);
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (widget.frequency - 1.0).clamp(400.0, 480.0);
    widget.onChanged(newValue);
  }

  void _reset() {
    widget.onChanged(440.0);
  }

  void _submitValue() {
    final value = double.tryParse(_controller.text);
    if (value != null) {
      widget.onChanged(value.clamp(400.0, 480.0));
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
        // Decrement button
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 16),
          onPressed: _decrement,
          tooltip: 'Decrease frequency',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        // Text input
        SizedBox(
          width: 50,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
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
            onSubmitted: (_) => _submitValue(),
            onEditingComplete: _submitValue,
          ),
        ),
        // Increment button
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
        // Reset button
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

