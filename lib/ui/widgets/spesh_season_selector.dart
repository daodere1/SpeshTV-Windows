import 'package:flutter/material.dart';

class SpeshSeasonSelector extends StatelessWidget {
  const SpeshSeasonSelector({super.key, required this.selected,
    required this.label, required this.options, required this.onChanged});
  final int selected;
  final String label;
  final Map<int, String> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey(selected),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries.map((entry) => DropdownMenuItem(
      value: entry.key,
      child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
    )).toList(),
    onChanged: (value) { if (value != null) onChanged(value); },
  );
}
