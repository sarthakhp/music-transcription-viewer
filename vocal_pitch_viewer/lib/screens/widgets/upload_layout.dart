import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/job.dart';
import '../../widgets/job_list_card.dart';
import 'upload_section.dart';

/// Upload layout widget with responsive design
class UploadLayout extends StatelessWidget {
  final AppState appState;
  final List<JobListItem> completedJobs;
  final bool isLoadingJobs;
  final Future<void> Function(String) onJobSelected;
  final Future<void> Function(String) onJobDeleted;
  final VoidCallback onUploadPressed;
  final bool isLoadingJson;
  final bool isLoadingAudio;
  final String? loadingAudioStatus;

  const UploadLayout({
    super.key,
    required this.appState,
    required this.completedJobs,
    required this.isLoadingJobs,
    required this.onJobSelected,
    required this.onJobDeleted,
    required this.onUploadPressed,
    this.isLoadingJson = false,
    this.isLoadingAudio = false,
    this.loadingAudioStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1000;

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
          padding: const EdgeInsets.all(32),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Upload section
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: UploadSection(
                              appState: appState,
                              onUploadPressed: onUploadPressed,
                              isLoadingJson: isLoadingJson,
                              isLoadingAudio: isLoadingAudio,
                              loadingAudioStatus: loadingAudioStatus,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right side - Job list
                    Expanded(
                      flex: 3,
                      child: JobListCard(
                        jobs: completedJobs,
                        onJobSelected: onJobSelected,
                        onJobDeleted: onJobDeleted,
                        isLoading: isLoadingJobs,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Upload section
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: UploadSection(
                          appState: appState,
                          onUploadPressed: onUploadPressed,
                          isLoadingJson: isLoadingJson,
                          isLoadingAudio: isLoadingAudio,
                          loadingAudioStatus: loadingAudioStatus,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Job list
                      SizedBox(
                        height: 400,
                        child: JobListCard(
                          jobs: completedJobs,
                          onJobSelected: onJobSelected,
                          onJobDeleted: onJobDeleted,
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
}

