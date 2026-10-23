import 'package:flutter/material.dart';
import '../../../services/cloud_upload/cloud_upload.dart';
import 'account_bar.dart';
import 'submission_list.dart';

/// The frame both upload panels share: a title, a Google sign-in (or, once
/// signed in, the account line and the panel's own [form]), then any error or
/// warning, then the songs already submitted.
class UploadCard extends StatelessWidget {
  final String title;
  final String? email;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final List<Widget> form;
  final String? error;
  final String? warning;
  final List<QueueStatus> submissions;

  const UploadCard({
    super.key,
    required this.title,
    required this.email,
    required this.busy,
    required this.onSignIn,
    required this.onSignOut,
    required this.form,
    required this.error,
    required this.warning,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (email == null)
              FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
              )
            else ...[
              AccountBar(email: email!, enabled: !busy, onSignOut: onSignOut),
              const SizedBox(height: 8),
              ...form,
            ],
            if (error != null) _message(error!, theme.colorScheme.error),
            if (warning != null) _message(warning!, theme.colorScheme.tertiary),
            if (submissions.isNotEmpty) ...[
              const Divider(height: 28),
              SubmissionList(items: submissions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, style: TextStyle(color: color)),
      );
}
