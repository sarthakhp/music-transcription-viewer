import 'package:flutter/material.dart';

/// Text box for pasting a link to a song (YouTube or another site).
class LinkField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const LinkField({super.key, required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Link (YouTube or other)',
        border: OutlineInputBorder(),
      ),
    );
  }
}
