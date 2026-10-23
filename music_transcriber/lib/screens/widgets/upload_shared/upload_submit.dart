import 'package:flutter/material.dart';
import 'source_selector.dart';

/// The send button and, while uploading, its progress bar. A link has no file
/// to upload, so its bar just spins instead of filling.
class UploadSubmit extends StatelessWidget {
  final UploadSource source;
  final bool enabled;
  final double? fraction;
  final VoidCallback onPressed;

  const UploadSubmit({
    super.key,
    required this.source,
    required this.enabled,
    required this.fraction,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isLink = source == UploadSource.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: Icon(isLink ? Icons.link_rounded : Icons.cloud_upload_rounded),
            label: const Text('Transcribe'),
          ),
        ),
        if (fraction != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: isLink ? null : fraction),
        ],
      ],
    );
  }
}
