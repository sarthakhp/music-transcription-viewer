import 'package:flutter/material.dart';
import '../../../models/instrument_catalog.dart';

/// Optional "which instruments are in this?" chooser. Ticking nothing lets the
/// transcriber work it out on its own; ticking some makes it look only for those.
/// Collapsed it shows a one-line summary; opened it offers a search box and the
/// instruments grouped by family.
class InstrumentPicker extends StatefulWidget {
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  const InstrumentPicker({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<InstrumentPicker> createState() => _InstrumentPickerState();
}

class _InstrumentPickerState extends State<InstrumentPicker> {
  final TextEditingController _search = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    final next = {...widget.selected};
    next.contains(id) ? next.remove(id) : next.add(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.enabled ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.piano_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Instruments', style: theme.textTheme.titleSmall),
                      Text(_summary(), style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        if (_open) _body(theme),
      ],
    );
  }

  String _summary() {
    if (widget.selected.isEmpty) return 'Automatic';
    final names = [for (final o in instrumentCatalog) if (widget.selected.contains(o.id)) o.label];
    return 'Looking only for: ${names.join(', ')}';
  }

  Widget _body(ThemeData theme) {
    final matches = searchInstruments(_search.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        TextField(
          controller: _search,
          enabled: widget.enabled,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search: flute, piano, harmonium, guitar…',
            border: const OutlineInputBorder(),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.selected.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? () => widget.onChanged({}) : null,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: Text('Clear all (${widget.selected.length} chosen)'),
            ),
          ),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Nothing matches "${_search.text}".', style: theme.textTheme.bodySmall),
          )
        else
          for (final family in InstrumentFamily.values) ..._familySection(theme, family, matches),
      ],
    );
  }

  List<Widget> _familySection(ThemeData theme, InstrumentFamily family, List<InstrumentOption> matches) {
    final inFamily = [for (final o in matches) if (o.family == family) o];
    if (inFamily.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(family.label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in inFamily)
            FilterChip(
              label: Text(option.label),
              selected: widget.selected.contains(option.id),
              onSelected: widget.enabled ? (_) => _toggle(option.id) : null,
            ),
        ],
      ),
    ];
  }
}
