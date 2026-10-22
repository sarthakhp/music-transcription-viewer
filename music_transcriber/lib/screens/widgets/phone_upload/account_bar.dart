import 'package:flutter/material.dart';

/// Google account line: who is signed in and a sign-out button.
class AccountBar extends StatelessWidget {
  final String email;
  final bool enabled;
  final VoidCallback onSignOut;

  const AccountBar({
    super.key,
    required this.email,
    required this.enabled,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(Icons.verified_user_rounded, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(child: Text(email, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
        TextButton(onPressed: enabled ? onSignOut : null, child: const Text('Sign out')),
      ],
    );
  }
}
