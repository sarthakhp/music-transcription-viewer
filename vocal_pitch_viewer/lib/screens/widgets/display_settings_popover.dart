import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Icon button that opens a floating confidence-threshold settings card
class DisplaySettingsButton extends StatefulWidget {
  final bool hasInstruments;
  final bool hasBass;
  final bool hasOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final ValueChanged<double> onVocalsConfidenceChanged;
  final ValueChanged<double> onBassConfidenceChanged;
  final ValueChanged<double> onOtherConfidenceChanged;
  final int vocalDetail;
  final ValueChanged<int> onVocalDetailChanged;

  const DisplaySettingsButton({
    super.key,
    required this.hasInstruments,
    required this.hasBass,
    required this.hasOther,
    required this.vocalsMinConfidence,
    required this.bassMinConfidence,
    required this.otherMinConfidence,
    required this.onVocalsConfidenceChanged,
    required this.onBassConfidenceChanged,
    required this.onOtherConfidenceChanged,
    this.vocalDetail = 10,
    required this.onVocalDetailChanged,
  });

  @override
  State<DisplaySettingsButton> createState() => _DisplaySettingsButtonState();
}

class _DisplaySettingsButtonState extends State<DisplaySettingsButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;
  bool _isOpen = false;

  @override
  void dispose() {
    _closePanel();
    super.dispose();
  }

  bool get _isFiltering =>
      widget.vocalsMinConfidence > 0 ||
      widget.bassMinConfidence > 0 ||
      widget.otherMinConfidence > 0;

  void _togglePanel() => _isOpen ? _closePanel() : _openPanel();

  void _openPanel() {
    _entry = OverlayEntry(
      builder: (_) => _PanelOverlay(
        layerLink: _layerLink,
        onDismiss: _closePanel,
        hasBass: widget.hasBass,
        hasOther: widget.hasOther,
        vocalsMinConfidence: widget.vocalsMinConfidence,
        bassMinConfidence: widget.bassMinConfidence,
        otherMinConfidence: widget.otherMinConfidence,
        onVocalsChanged: widget.onVocalsConfidenceChanged,
        onBassChanged: widget.onBassConfidenceChanged,
        onOtherChanged: widget.onOtherConfidenceChanged,
        vocalDetail: widget.vocalDetail,
        onVocalDetailChanged: widget.onVocalDetailChanged,
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() => _isOpen = true);
  }

  void _closePanel() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = _isOpen ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.55);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: 'Display settings',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _togglePanel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: activeColor),
                // Small dot when confidence filtering is active
                if (_isFiltering)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay panel with per-layer confidence sliders
class _PanelOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final VoidCallback onDismiss;
  final bool hasBass;
  final bool hasOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final ValueChanged<double> onVocalsChanged;
  final ValueChanged<double> onBassChanged;
  final ValueChanged<double> onOtherChanged;
  final int vocalDetail;
  final ValueChanged<int> onVocalDetailChanged;

  const _PanelOverlay({
    required this.layerLink,
    required this.onDismiss,
    required this.hasBass,
    required this.hasOther,
    required this.vocalsMinConfidence,
    required this.bassMinConfidence,
    required this.otherMinConfidence,
    required this.onVocalsChanged,
    required this.onBassChanged,
    required this.onOtherChanged,
    this.vocalDetail = 10,
    required this.onVocalDetailChanged,
  });

  @override
  State<_PanelOverlay> createState() => _PanelOverlayState();
}

class _PanelOverlayState extends State<_PanelOverlay> {
  late double _vocals;
  late double _bass;
  late double _other;
  late int _detail;

  @override
  void initState() {
    super.initState();
    _vocals = widget.vocalsMinConfidence;
    _bass = widget.bassMinConfidence;
    _other = widget.otherMinConfidence;
    _detail = widget.vocalDetail;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        // Transparent backdrop — tap to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        // Floating card anchored to the button's bottom-right corner
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHigh,
            child: Container(
              width: 270,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Display Settings',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Vocal detail slider
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('Vocal Detail', style: theme.textTheme.bodySmall),
                      ),
                      Expanded(
                        child: Slider(
                          value: _detail.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          onChanged: (v) {
                            final intVal = v.round();
                            setState(() => _detail = intVal);
                            widget.onVocalDetailChanged(intVal);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$_detail',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
                  const SizedBox(height: 10),
                  _SliderRow(
                    label: 'Vocals',
                    color: colorScheme.primary,
                    value: _vocals,
                    onChanged: (v) {
                      setState(() => _vocals = v);
                      widget.onVocalsChanged(v);
                    },
                  ),
                  if (widget.hasOther) ...[
                    const SizedBox(height: 6),
                    _SliderRow(
                      label: 'Other',
                      color: appPalette.otherColor,
                      value: _other,
                      onChanged: (v) {
                        setState(() => _other = v);
                        widget.onOtherChanged(v);
                      },
                    ),
                  ],
                  if (widget.hasBass) ...[
                    const SizedBox(height: 6),
                    _SliderRow(
                      label: 'Bass',
                      color: appPalette.bassColor,
                      value: _bass,
                      onChanged: (v) {
                        setState(() => _bass = v);
                        widget.onBassChanged(v);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              overlayColor: color.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
