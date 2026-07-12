import 'package:flutter/material.dart';
import '../models/job.dart';

/// Widget to display a list of jobs (completed history, or failed jobs that
/// can be retried).
class JobListCard extends StatelessWidget {
  final List<JobListItem> jobs;
  final Function(String jobId) onJobSelected;
  final Future<void> Function(String jobId)? onJobDeleted;
  final Future<void> Function(String jobId)? onJobRetry;
  final bool isLoading;

  /// Header title. Defaults to the completed-jobs history title.
  final String title;

  /// Render in the "failed" style — warning accent, retry affordance, and the
  /// error message instead of metrics. Tapping a tile triggers retry rather
  /// than opening the (non-existent) results.
  final bool isFailedList;

  /// Size to content instead of expanding to fill available height. Used when
  /// the card is stacked above another list in a Column.
  final bool shrinkWrap;

  const JobListCard({
    super.key,
    required this.jobs,
    required this.onJobSelected,
    this.onJobDeleted,
    this.onJobRetry,
    this.isLoading = false,
    this.title = 'Previous Jobs',
    this.isFailedList = false,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading previous jobs...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No previous jobs',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload an audio file to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final accentColor = isFailedList ? colorScheme.error : colorScheme.primary;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final listView = ListView.separated(
      padding: const EdgeInsets.all(12),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const ClampingScrollPhysics() : null,
      itemCount: jobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _JobListTile(
          job: job,
          isFailed: isFailedList,
          onTap: isFailedList
              ? (onJobRetry != null ? () => onJobRetry!(job.id) : () {})
              : () => onJobSelected(job.id),
          onDelete: onJobDeleted != null ? () => onJobDeleted!(job.id) : null,
          onRetry: onJobRetry != null ? () => onJobRetry!(job.id) : null,
        );
      },
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Row(
              children: [
                Icon(
                  isFailedList ? Icons.error_outline_rounded : Icons.history_rounded,
                  color: accentColor,
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${jobs.length} ${jobs.length == 1 ? 'job' : 'jobs'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (shrinkWrap) Flexible(child: listView) else Expanded(child: listView),
        ],
      ),
    );
  }
}

/// Individual job list tile
class _JobListTile extends StatefulWidget {
  final JobListItem job;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onRetry;
  final bool isFailed;

  const _JobListTile({
    required this.job,
    required this.onTap,
    this.onDelete,
    this.onRetry,
    this.isFailed = false,
  });

  @override
  State<_JobListTile> createState() => _JobListTileState();
}

class _JobListTileState extends State<_JobListTile> {
  bool _isHovered = false;
  bool _isDeleting = false;
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (widget.onRetry == null) return;
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.onDelete == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text(
          'Are you sure you want to delete "${widget.job.displayName}"?\n\nThis will permanently delete all associated data including audio stems and processing results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await widget.onDelete!();
      } finally {
        // Reset deleting state if widget is still mounted
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Card(
          elevation: _isHovered ? 2 : 0,
          child: Stack(
            children: [
              InkWell(
                onTap: _isDeleting ? null : widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: icon, title, trailing action — never grows with
                      // content, so it can't overflow regardless of screen width.
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.isFailed
                                  ? colorScheme.errorContainer
                                  : colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.job.isUrlSource
                                  ? Icons.link_rounded
                                  : Icons.music_note_rounded,
                              color: widget.isFailed
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.job.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: colorScheme.error,
                              tooltip: 'Delete job',
                              onPressed: _isDeleting ? null : _handleDelete,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            )
                          else if (!widget.isFailed)
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.3),
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Row 2: metadata — wraps instead of overflowing on
                      // narrow screens, and the timestamp is free to drop to
                      // its own line rather than clipping other content.
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: widget.isFailed
                            ? Text(
                                widget.job.errorMessage?.isNotEmpty == true
                                    ? widget.job.errorMessage!
                                    : 'Processing failed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error.withValues(alpha: 0.9),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Wrap(
                                spacing: 12,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Stat(
                                    icon: Icons.access_time_rounded,
                                    label: widget.job.durationFormatted,
                                  ),
                                  _Stat(
                                    icon: Icons.speed_rounded,
                                    label: '${widget.job.tempoBpm.toStringAsFixed(0)} BPM',
                                  ),
                                  _Stat(
                                    icon: Icons.library_music_rounded,
                                    label: '${widget.job.numChords} chords',
                                  ),
                                  Text(
                                    widget.job.createdAtFormatted,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Row 3 (failed only): timestamp + full-width Retry —
                      // a real touch target, not a hover-only affordance.
                      if (widget.isFailed) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 38),
                          child: Row(
                            children: [
                              Text(
                                widget.job.createdAtFormatted,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              const Spacer(),
                              if (widget.onRetry != null)
                                FilledButton.tonalIcon(
                                  onPressed: _isRetrying ? null : _handleRetry,
                                  icon: _isRetrying
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 16),
                                  label: Text(_isRetrying ? 'Retrying' : 'Retry'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Deleting overlay
              if (_isDeleting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Deleting...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon+label pair used inside the metadata [Wrap] on a job tile.
class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

