import 'package:flutter/material.dart';

class SpeshEmptyResults extends StatelessWidget {
  const SpeshEmptyResults({super.key, required this.title, this.onClearFilters,
    this.onClearSearch, this.clearFiltersLabel = 'Clear filters'});
  final String title, clearFiltersLabel;
  final VoidCallback? onClearFilters, onClearSearch;

  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      if (onClearFilters != null || onClearSearch != null) ...[
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
          if (onClearFilters != null) TextButton.icon(onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off), label: Text(clearFiltersLabel)),
          if (onClearSearch != null) TextButton.icon(onPressed: onClearSearch,
            icon: const Icon(Icons.search_off), label: const Text('Clear search')),
        ]),
      ],
    ]),
  ));
}
