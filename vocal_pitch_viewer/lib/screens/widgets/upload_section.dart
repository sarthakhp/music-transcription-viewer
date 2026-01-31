import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../widgets/processing_status_card.dart';

/// Upload section widget with animated branding and upload button
class UploadSection extends StatelessWidget {
  final AppState appState;
  final VoidCallback onUploadPressed;
  final bool isLoadingJson;
  final bool isLoadingAudio;
  final String? loadingAudioStatus;

  const UploadSection({
    super.key,
    required this.appState,
    required this.onUploadPressed,
    this.isLoadingJson = false,
    this.isLoadingAudio = false,
    this.loadingAudioStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated app icon with glow effect
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.6),
                  colorScheme.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Title with delayed animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Text(
            'Vocal Pitch Viewer',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Subtitle
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Text(
            'Upload an audio file to visualize pitch and chords',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),

        // Loading indicator
        if (isLoadingJson || isLoadingAudio)
          Column(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              if (loadingAudioStatus != null)
                Text(
                  loadingAudioStatus!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  isLoadingJson ? 'Loading pitch data...' : 'Loading audio...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),

        // Error message with animation
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: appState.errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            appState.errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.error),
                          onPressed: () => appState.setError(null),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Processing status card
        const ProcessingStatusCard(),

        // Upload button for API
        if (!appState.isUploading && !appState.isProcessing)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: FilledButton.tonalIcon(
              onPressed: onUploadPressed,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Audio for Processing'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

