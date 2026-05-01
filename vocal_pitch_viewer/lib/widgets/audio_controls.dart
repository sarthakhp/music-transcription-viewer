import 'package:flutter/material.dart';
import '../utils/music_utils.dart';

/// Audio playback controls widget
class AudioControls extends StatelessWidget {
  static const double seekStepSeconds = 1;
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
  final int transposeAmount;
  final ValueChanged<int> onTransposeChanged;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool sargamEnabled;
  final ValueChanged<bool> onSargamToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;

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
    required this.transposeAmount,
    required this.onTransposeChanged,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.sargamEnabled,
    required this.onSargamToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
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
                icon: const Icon(Icons.replay_rounded),
                onPressed: () => onSeek((currentTime - seekStepSeconds).clamp(0, duration)),
                tooltip: 'Back ${seekStepSeconds.toInt()}s',
              ),
              IconButton(
                icon: Transform.flip(flipX: true, child: const Icon(Icons.replay_rounded)),
                onPressed: () => onSeek((currentTime + seekStepSeconds).clamp(0, duration)),
                tooltip: 'Forward ${seekStepSeconds.toInt()}s',
              ),
              const SizedBox(width: 8),
              _SpeedControl(
                speed: playbackSpeed,
                onChanged: onSpeedChanged,
              ),
              const Spacer(),
              // Transpose control
              _TransposeControl(
                amount: transposeAmount,
                onChanged: onTransposeChanged,
              ),
              const SizedBox(width: 16),
              // Sargam controls
              _SargamControl(
                enabled: sargamEnabled,
                onToggled: onSargamToggled,
                scaleRoot: scaleRoot,
                onScaleRootChanged: onScaleRootChanged,
              ),
              const SizedBox(width: 16),
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

/// Compact playback speed control with preset steps
class _SpeedControl extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;

  static const List<double> _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  const _SpeedControl({required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = speed != 1.0;
    final currentIndex = _presets.indexOf(speed);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 16),
          onPressed: currentIndex > 0
              ? () => onChanged(_presets[currentIndex - 1])
              : null,
          tooltip: 'Slower  [',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        GestureDetector(
          onTap: isActive ? () => onChanged(1.0) : null,
          child: Container(
            width: 44,
            alignment: Alignment.center,
            decoration: isActive
                ? BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '${speed}x',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isActive ? colorScheme.onPrimaryContainer : null,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 16),
          onPressed: currentIndex < _presets.length - 1
              ? () => onChanged(_presets[currentIndex + 1])
              : null,
          tooltip: 'Faster  ]',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// Compact transpose stepper (–12 to +12 semitones)
class _TransposeControl extends StatefulWidget {
  final int amount;
  final ValueChanged<int> onChanged;

  const _TransposeControl({required this.amount, required this.onChanged});

  @override
  State<_TransposeControl> createState() => _TransposeControlState();
}

class _TransposeControlState extends State<_TransposeControl> {
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
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value != null) {
      widget.onChanged(value.clamp(-12, 12));
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Key:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 16),
          onPressed: widget.amount > -12 ? () => widget.onChanged(widget.amount - 1) : null,
          tooltip: 'Transpose down',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        GestureDetector(
          onTap: _startEditing,
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
            child: _editing
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
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
                    onSubmitted: (_) => _submit(),
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
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 16),
          onPressed: widget.amount < 12 ? () => widget.onChanged(widget.amount + 1) : null,
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
    );
  }
}

/// Sargam notation toggle with scale root selector
class _SargamControl extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;

  const _SargamControl({
    required this.enabled,
    required this.onToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scale root dropdown (only meaningful when Sargam is on, but always visible)
        Text(
          'Root:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          child: DropdownButton<int>(
            value: scaleRoot,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            items: List.generate(12, (i) => DropdownMenuItem(
              value: i,
              child: Text(noteNames[i]),
            )),
            onChanged: (v) {
              if (v != null) onScaleRootChanged(v);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Sargam toggle
        Tooltip(
          message: enabled ? 'Switch to Western notation' : 'Switch to Sargam notation',
          child: InkWell(
            onTap: () => onToggled(!enabled),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: enabled ? colorScheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(4),
                border: enabled
                    ? null
                    : Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Sa Re Ga',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ],
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
          width: 62,
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

