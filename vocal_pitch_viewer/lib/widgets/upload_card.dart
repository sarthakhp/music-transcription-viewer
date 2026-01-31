import 'package:flutter/material.dart';

/// A beautiful upload card widget with loading state and hover effects
class UploadCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoaded;
  final bool isLoading;
  final String? loadingStatus; // Detailed loading status message
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const UploadCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoaded,
    this.isLoading = false,
    this.loadingStatus,
    required this.onTap,
    this.onClear,
  });

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Start pulse animation when not loaded
    if (!widget.isLoaded && !widget.isLoading) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(UploadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Stop pulse when loaded
    if (widget.isLoaded || widget.isLoading) {
      _pulseController.stop();
      _pulseController.reset();
    } else if (!oldWidget.isLoaded && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.isLoaded ? 1.0 : _pulseAnimation.value;
          return Transform.scale(
            scale: _isHovered && !widget.isLoaded ? 1.02 : scale,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_isHovered && !widget.isLoaded)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Card(
            elevation: _isHovered ? 4 : 0,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon container with animated background
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isLoaded
                            ? colorScheme.primaryContainer
                            : _isHovered
                                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: widget.isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                widget.isLoaded ? Icons.check_rounded : widget.icon,
                                key: ValueKey(widget.isLoaded),
                                color: widget.isLoaded || _isHovered
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: widget.isLoading && widget.loadingStatus != null
                                  ? colorScheme.tertiary
                                  : widget.isLoaded
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withValues(alpha: 0.6),
                              fontStyle: widget.isLoading && widget.loadingStatus != null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            child: Text(
                              widget.isLoading && widget.loadingStatus != null
                                  ? widget.loadingStatus!
                                  : widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    if (widget.isLoaded && widget.onClear != null)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        onPressed: widget.onClear,
                        tooltip: 'Clear',
                      )
                    else if (!widget.isLoading)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered ? 1.0 : 0.4,
                        child: Icon(
                          Icons.upload_file_rounded,
                          size: 20,
                          color: _isHovered ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

