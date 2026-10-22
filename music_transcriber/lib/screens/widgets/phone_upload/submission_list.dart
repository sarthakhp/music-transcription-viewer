import 'package:flutter/material.dart';
import '../../../services/cloud_upload/cloud_upload.dart';

/// One line per submitted song with its current processing state.
class SubmissionList extends StatelessWidget {
  final List<QueueStatus> items;
  const SubmissionList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        for (final s in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_icon(s), color: s.isFailed ? errorColor : null),
            title: Text(s.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_describe(s)),
          ),
      ],
    );
  }

  static IconData _icon(QueueStatus s) {
    if (s.isDone) return Icons.check_circle_rounded;
    if (s.isFailed) return Icons.error_rounded;
    return Icons.hourglass_top_rounded;
  }

  static String _describe(QueueStatus s) {
    switch (s.status) {
      case 'done':
        return 'Done, in your songs';
      case 'failed':
        return 'Failed${s.error == null ? '' : ': ${s.error}'}';
      case 'queued':
        return 'Waiting for your Mac to pick it up';
      default:
        return '${s.stage ?? 'Starting'} · ${s.progress}%';
    }
  }
}
