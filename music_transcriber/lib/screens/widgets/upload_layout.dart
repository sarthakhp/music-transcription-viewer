import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/job.dart';
import '../../services/transcription_api_service.dart';
import '../../widgets/job_list_card.dart';
import '../practice_screen.dart';
import 'upload_section.dart';

/// Upload layout widget with responsive design
class UploadLayout extends StatelessWidget {
  final AppState appState;
  final TranscriptionApiService apiService;
  final List<JobListItem> completedJobs;
  final List<JobListItem> failedJobs;
  final bool isLoadingJobs;
  final Future<void> Function(String) onJobSelected;
  final Future<void> Function(String) onJobDeleted;
  final Future<void> Function(String) onJobRetry;
  final Future<void> Function(Uint8List bytes, String fileName)? onFileUpload;
  final bool isRemote;
  final Future<void> Function(String url, {double? startTime, double? endTime})? onUrlSubmitted;
  final Future<void> Function()? onCancel;
  final bool isLoadingJson;
  final bool isLoadingAudio;
  final String? loadingAudioStatus;

  const UploadLayout({
    super.key,
    required this.appState,
    required this.apiService,
    required this.completedJobs,
    required this.failedJobs,
    required this.isLoadingJobs,
    required this.onJobSelected,
    required this.onJobDeleted,
    required this.onJobRetry,
    this.onFileUpload,
    this.onUrlSubmitted,
    this.onCancel,
    this.isLoadingJson = false,
    this.isLoadingAudio = false,
    this.loadingAudioStatus,
    this.isRemote = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;
    final isMobile = screenWidth < 600;
    final outerPadding = isMobile ? 16.0 : 32.0;

    return Stack(
      children: [
        // Subtle gradient background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.5,
                colors: [
                  colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: EdgeInsets.all(outerPadding),
          child: isWide
              ? (appState.isProcessing || appState.isUploading)
                  // During processing: full-width left panel, no job list
                  ? Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _leftPanel(context),
                        ),
                      ),
                    )
                  : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Upload section
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: _leftPanel(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right side - Job lists (failed retryable + completed history)
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          if (failedJobs.isNotEmpty) ...[
                            Flexible(
                              child: JobListCard(
                                jobs: failedJobs,
                                title: 'Failed — Retry',
                                isFailedList: true,
                                shrinkWrap: true,
                                onJobSelected: onJobSelected,
                                onJobDeleted: onJobDeleted,
                                onJobRetry: onJobRetry,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Expanded(
                            child: JobListCard(
                              jobs: completedJobs,
                              onJobSelected: onJobSelected,
                              onJobDeleted: isRemote ? null : onJobDeleted,
                              isLoading: isLoadingJobs,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Upload section (or hosted-viewer note in remote mode)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _leftPanel(context),
                      ),
                      SizedBox(height: isMobile ? 20 : 32),
                      // Failed jobs (retryable) — sized to content
                      if (failedJobs.isNotEmpty) ...[
                        JobListCard(
                          jobs: failedJobs,
                          title: 'Failed — Retry',
                          isFailedList: true,
                          shrinkWrap: true,
                          onJobSelected: onJobSelected,
                          onJobDeleted: onJobDeleted,
                          onJobRetry: onJobRetry,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Completed job history
                      SizedBox(
                        height: 400,
                        child: JobListCard(
                          jobs: completedJobs,
                          onJobSelected: onJobSelected,
                          onJobDeleted: isRemote ? null : onJobDeleted,
                          isLoading: isLoadingJobs,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Left panel: the upload/URL controls locally, or a read-only note when
  /// running as the hosted viewer (no processing backend available). Either
  /// way, the fully client-side Practice Mode entry point is offered too.
  Widget _leftPanel(BuildContext context) {
    if (!isRemote) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UploadSection(
            appState: appState,
            apiService: apiService,
            onFileUpload: onFileUpload,
            onUrlSubmitted: onUrlSubmitted,
            onCancel: onCancel,
            isLoadingJson: isLoadingJson,
            isLoadingAudio: isLoadingAudio,
            loadingAudioStatus: loadingAudioStatus,
          ),
          const SizedBox(height: 20),
          _practiceModeCard(context),
        ],
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text('Music Transcriber',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Browse your transcribed library. Select a track to view its pitch, '
                  'chords, and instruments.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hosted, read-only. Run the app locally to transcribe new audio.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _practiceModeCard(context),
      ],
    );
  }

  /// Entry point for the fully client-side, backend-free Practice Mode —
  /// shown regardless of local/remote mode, since it needs neither.
  Widget _practiceModeCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Just want to practice?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Upload any audio file to transpose its key or change its speed, '
              'entirely in your browser — no transcription needed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PracticeScreen()),
              ),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Open Practice Mode'),
            ),
          ],
        ),
      ),
    );
  }
}

