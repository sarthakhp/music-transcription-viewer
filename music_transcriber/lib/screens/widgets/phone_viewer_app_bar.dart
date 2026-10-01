import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../providers/theme_provider.dart';

/// App bar for the viewer on phones.
///
/// Shows what matters while practicing — the track name and its stats — in
/// place of the app title, with a back button to the library. Rarely used
/// actions (rename, download, theme) collapse into one overflow menu so the
/// title gets the space.
class PhoneViewerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppState appState;
  final Widget tanpuraButton;
  final VoidCallback onBack;
  final ValueChanged<String> onRename;
  final bool isExporting;
  final double exportProgress;
  final Future<void> Function(String stemLabel, Uint8List bytes) onDownload;
  final VoidCallback onThemeToggle;
  final bool compactHeight;

  /// Extra controls shown before the tanpura button (landscape layer chips).
  final Widget? inlineControls;

  const PhoneViewerAppBar({
    super.key,
    required this.appState,
    required this.tanpuraButton,
    required this.onBack,
    required this.onRename,
    required this.isExporting,
    required this.exportProgress,
    required this.onDownload,
    required this.onThemeToggle,
    this.compactHeight = false,
    this.inlineControls,
  });

  @override
  Size get preferredSize => Size.fromHeight(compactHeight ? 48 : 60);

  String get _stats {
    final parts = <String>[
      if (appState.pitchData != null) appState.pitchData!.durationFormatted,
      if (appState.pitchData?.metadata.bpm != null)
        '${appState.pitchData!.metadata.bpm!.round()} BPM',
      if (appState.chordData != null) '${appState.chordData!.uniqueChordsCount} chords',
    ];
    return parts.join('  ·  ');
  }

  Future<void> _promptRename(BuildContext context) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: appState.audioFileName ?? ''),
    );
    final trimmed = newName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) onRename(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stems = <(String, String, Uint8List?)>[
      ('original', 'Original', appState.originalAudio),
      ('vocals', 'Vocals', appState.vocalsAudio),
      ('instrumental', 'Instrumental', appState.instrumentalAudio),
    ].where((s) => s.$3 != null).toList();

    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back to library',
        onPressed: onBack,
      ),
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _promptRename(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appState.audioFileName ?? 'Audio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!compactHeight && _stats.isNotEmpty)
                Text(
                  _stats,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (inlineControls != null) inlineControls!,
        tanpuraButton,
        if (isExporting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: exportProgress > 0 ? exportProgress : null,
              ),
            ),
          )
        else
          PopupMenuButton<VoidCallback>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onSelected: (action) => action(),
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: () => _promptRename(context),
                child: const ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Rename'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              for (final stem in stems)
                PopupMenuItem(
                  value: () => onDownload(stem.$1, stem.$3!),
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text('Download ${stem.$2}'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: onThemeToggle,
                child: ListTile(
                  leading: Icon(menuContext.read<ThemeProvider>().themeModeIcon),
                  title: const Text('Change theme'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Owns its [TextEditingController] so it is disposed only after the dialog's
/// exit animation has finished.
class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename track'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
