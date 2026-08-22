import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/job_status.dart';

/// Widget to display job processing status with progress
class ProcessingStatusCard extends StatefulWidget {
  final Future<void> Function()? onCancel;

  const ProcessingStatusCard({super.key, this.onCancel});

  @override
  State<ProcessingStatusCard> createState() => _ProcessingStatusCardState();
}

class _ProcessingStatusCardState extends State<ProcessingStatusCard> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Don't show if not uploading, processing, or failed
        if (!appState.isUploading && !appState.isProcessing && !appState.isJobFailed) {
          return const SizedBox.shrink();
        }

        // Show error card when job has failed
        if (appState.isJobFailed) {
          return Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Processing Failed',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        if (appState.errorMessage != null &&
                            appState.errorMessage!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(appState.errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
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

                // Cancel button
                if (widget.onCancel != null && !appState.isUploading) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _isCancelling
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancelling...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          )
                        : TextButton(
                            onPressed: _handleCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Cancel'),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel processing?'),
        content: const Text(
          'All progress will be lost. The audio file will need to be re-uploaded to try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Processing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCancelling = true);
      try {
        await widget.onCancel!();
      } finally {
        if (mounted) {
          setState(() => _isCancelling = false);
        }
      }
    }
  }

  /// Build stage indicator showing all stages
  Widget _buildStageIndicator(BuildContext context, AppState appState) {
    final currentStage = appState.processingStage;
    final stageProgress = appState.stageProgress;
    // Show the download stage only when it's active or has been passed.
    final showDownload = currentStage == ProcessingStage.download ||
        (currentStage != null && currentStage.index > ProcessingStage.download.index);

    return Row(
      children: [
        if (showDownload) ...[
          _buildStageChip(
            context,
            'Download',
            ProcessingStage.download,
            currentStage,
            stageProgress,
          ),
          const SizedBox(width: 8),
        ],
        _buildStageChip(
          context,
          'Separation',
          ProcessingStage.separation,
          currentStage,
          stageProgress,
        ),
        const SizedBox(width: 8),
        _buildStageChip(
          context,
          'Transcription',
          ProcessingStage.transcription,
          currentStage,
          stageProgress,
        ),
        const SizedBox(width: 8),
        _buildStageChip(
          context,
          'Instruments',
          ProcessingStage.instruments,
          currentStage,
          stageProgress,
        ),
        const SizedBox(width: 8),
        _buildStageChip(
          context,
          'Chords',
          ProcessingStage.chords,
          currentStage,
          stageProgress,
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
    int stageProgress,
  ) {
    final isActive = currentStage == stage;
    final isPast = currentStage != null &&
        currentStage.index > stage.index;

    final baseColor = isActive
        ? Theme.of(context).colorScheme.primaryContainer
        : isPast
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest;

    final contentColor = isActive
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : isPast
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant;

    Widget chipContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isPast)
          Icon(Icons.check_circle, size: 16, color: contentColor)
        else if (isActive)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: contentColor,
            ),
          )
        else
          Icon(Icons.circle_outlined, size: 16, color: contentColor),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: contentColor,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isActive)
                Text(
                  '$stageProgress%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Base background
            Positioned.fill(child: Container(color: baseColor)),
            // Fill overlay for active stage
            if (isActive)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: stageProgress / 100,
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25),
                  ),
                ),
              ),
            // Content rendered once on top
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: chipContent,
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

    // Use message from API if available
    if (appState.processingMessage != null && appState.processingMessage!.isNotEmpty) {
      return appState.processingMessage!;
    }

    // Fallback to stage-based messages
    if (appState.processingStage != null) {
      switch (appState.processingStage!) {
        case ProcessingStage.download:
          return 'Downloading audio from URL';
        case ProcessingStage.separation:
          return 'Separating audio into stems (vocals, instruments)';
        case ProcessingStage.transcription:
          return 'Detecting pitch and transcribing vocals';
        case ProcessingStage.instruments:
          return 'Transcribing instrument notes (bass, melodic)';
        case ProcessingStage.chords:
          return 'Analyzing chord progression';
      }
    }

    return 'Processing your audio file';
  }
}

