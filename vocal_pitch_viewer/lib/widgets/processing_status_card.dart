import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/job_status.dart';

/// Widget to display job processing status with progress
class ProcessingStatusCard extends StatelessWidget {
  const ProcessingStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Don't show if not uploading or processing
        if (!appState.isUploading && !appState.isProcessing) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(appState),
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getStatusTitle(appState),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress bar
                LinearProgressIndicator(
                  value: appState.isUploading 
                      ? null // Indeterminate for upload
                      : appState.processingProgress / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),

                // Progress text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _getStatusMessage(appState),
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!appState.isUploading) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${appState.processingProgress}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                // Stage information
                if (appState.processingStage != null) ...[
                  const SizedBox(height: 12),
                  _buildStageIndicator(context, appState),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build stage indicator showing all 3 stages
  Widget _buildStageIndicator(BuildContext context, AppState appState) {
    final currentStage = appState.processingStage;
    
    return Row(
      children: [
        _buildStageChip(
          context,
          'Separation',
          ProcessingStage.separation,
          currentStage,
        ),
        const SizedBox(width: 8),
        _buildStageChip(
          context,
          'Transcription',
          ProcessingStage.transcription,
          currentStage,
        ),
        const SizedBox(width: 8),
        _buildStageChip(
          context,
          'Chords',
          ProcessingStage.chords,
          currentStage,
        ),
      ],
    );
  }

  /// Build individual stage chip
  Widget _buildStageChip(
    BuildContext context,
    String label,
    ProcessingStage stage,
    ProcessingStage? currentStage,
  ) {
    final isActive = currentStage == stage;
    final isPast = currentStage != null && 
        currentStage.index > stage.index;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : isPast
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPast)
              Icon(
                Icons.check_circle,
                size: 16,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              )
            else if (isActive)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            else
              Icon(
                Icons.circle_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : isPast
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(AppState appState) {
    if (appState.isUploading) return Icons.cloud_upload;
    if (appState.isProcessing) return Icons.auto_fix_high;
    return Icons.check_circle;
  }

  String _getStatusTitle(AppState appState) {
    if (appState.isUploading) return 'Uploading Audio File...';
    if (appState.isProcessing) return 'Processing Audio...';
    return 'Complete';
  }

  String _getStatusMessage(AppState appState) {
    if (appState.isUploading) {
      return 'Uploading your audio file to the server';
    }
    
    if (appState.processingStage != null) {
      switch (appState.processingStage!) {
        case ProcessingStage.separation:
          return 'Separating audio into stems (vocals, instruments)';
        case ProcessingStage.transcription:
          return 'Detecting pitch and transcribing vocals';
        case ProcessingStage.chords:
          return 'Analyzing chord progression';
      }
    }
    
    return 'Processing your audio file';
  }
}

