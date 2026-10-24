import 'package:flutter/material.dart';
import '../../../services/cloud_upload/queue_status.dart';

/// One line per submitted song: what is happening to it, an Open button once it
/// is ready, and a way to dismiss it when it is finished.
class SubmissionList extends StatelessWidget {
  final List<QueueStatus> items;
  final void Function(String jobId) onOpen;
  final void Function(String requestId) onDismiss;

  /// The name of a finished song in the song list, if it is there. It follows
  /// renames, and beats the name we remembered.
  final String? Function(String jobId) titleForJob;

  const SubmissionList({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onDismiss,
    required this.titleForJob,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final item in items) _tile(context, item)],
    );
  }

  Widget _tile(BuildContext context, QueueStatus s) {
    final errorColor = Theme.of(context).colorScheme.error;
    final canOpen = s.isDone && s.jobId != null;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: _leading(s, errorColor),
      title: Text(displayName(s), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(describe(s)),
      onTap: canOpen ? () => onOpen(s.jobId!) : null,
      trailing: s.isActive
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canOpen) TextButton(onPressed: () => onOpen(s.jobId!), child: const Text('Open')),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: () => onDismiss(s.id),
                ),
              ],
            ),
    );
  }

  /// What to call a submission: the song's name in the list, else the name the
  /// worker reported, else what we remembered (a link is shortened to a
  /// readable form).
  String displayName(QueueStatus s) {
    final fromList = s.jobId == null ? null : titleForJob(s.jobId!);
    return fromList ?? shortenLink(s.fileName);
  }

  Widget _leading(QueueStatus s, Color errorColor) {
    if (s.isDone) return const Icon(Icons.check_circle_rounded);
    if (s.isFailed) return Icon(Icons.error_rounded, color: errorColor);
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }

  /// "https://www.youtube.com/watch?v=abc" -> "youtube.com/watch?v=abc"; anything
  /// that is not a link is returned unchanged.
  static String shortenLink(String label) {
    final uri = Uri.tryParse(label);
    if (uri == null || !uri.hasAuthority || !label.startsWith('http')) return label;
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    final rest = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    return rest == '/' ? host : '$host$rest';
  }

  /// The one line of status under a song's name.
  static String describe(QueueStatus s) {
    switch (s.status) {
      case 'done':
        return 'Ready in your songs';
      case 'failed':
        return 'Failed${s.error == null ? '' : ': ${s.error}'}';
      case 'checking':
        return 'Checking…';
      case 'queued':
        // Links download only on the Mac (video sites block cloud servers).
        return s.fileName.startsWith('http')
            ? 'Waiting for your Mac. Open the Mac app to start this link'
            : 'Queued. Starts as soon as a worker is free';
      default:
        return '${s.stage ?? 'Starting'} · ${s.progress}%';
    }
  }
}
