import 'package:flutter/material.dart';
import '../../../../data/models/channel_facets.dart';
import '../../../../data/viewmodels/live_tv_guide_view_model.dart';

class SpeshChannelFilters extends StatelessWidget {
  const SpeshChannelFilters({super.key, required this.model, required this.onChanged, this.onClearRecent});
  final LiveTvGuideViewModel model;
  final VoidCallback onChanged;
  final VoidCallback? onClearRecent;

  Widget _selector(String label, String value, List<ChannelFilterOption> options, ValueChanged<String> select) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        isExpanded: true, isDense: true, value: value, menuMaxHeight: 320,
        items: [
          const DropdownMenuItem(value: '', child: Text('All')),
          ...options.map((option) => DropdownMenuItem(value: option.value,
            child: Text('${option.value} (${option.count})', maxLines: 1, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (next) { if (next != null) { select(next); onChanged(); } },
      )),
    );
  }

  List<Widget> _selectors() => [
    _selector('Country', model.country, model.countryOptions, (v) => model.setChannelFilters(country: v)),
    _selector('Sports package', model.package, model.packageOptions, (v) => model.setChannelFilters(package: v)),
    _selector('Tag / group', model.tag, model.tagOptions, (v) => model.setChannelFilters(tag: v)),
  ];

  bool get _active => model.activeChannelFilterCount > 0;
  String get _count => '${model.filteredChannels.length} of ${model.channels.length} channels'
      '${_active ? ' | ${model.activeChannelFilterCount} active filters' : ''}';
  void _clear() { model.clearBrowseFilters(); onChanged(); }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
      builder: (sheetContext) => ListenableBuilder(listenable: model, builder: (context, _) =>
        Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [const Expanded(child: Text('Channel filters', style: TextStyle(fontSize: 18))),
              IconButton(tooltip: 'Clear channel filters', onPressed: _active ? _clear : null, icon: const Icon(Icons.filter_alt_off)),
              IconButton(tooltip: 'Close channel filters', onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close))]),
            const SizedBox(height: 12),
            for (final selector in _selectors()) ...[selector, const SizedBox(height: 16)],
            Text(_count),
          ],
        ))),
      ));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth < 820) {
      final selections = [model.country, model.package, model.tag].where((v) => v.isNotEmpty).join(' / ');
      return Row(children: [
        TextButton.icon(onPressed: () => _open(context), icon: const Icon(Icons.tune),
          label: Text(_active ? 'Filters (${model.activeChannelFilterCount})' : 'Filters')),
        const SizedBox(width: 8),
        Expanded(child: Text(selections.isEmpty ? _count : selections, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (_active) IconButton(tooltip: 'Clear channel filters', onPressed: _clear, icon: const Icon(Icons.filter_alt_off)),
        if (model.filter == GuideFilter.recentlyWatched && onClearRecent != null)
          IconButton(tooltip: 'Clear recently watched channels', onPressed: onClearRecent, icon: const Icon(Icons.history_toggle_off)),
      ]);
    }
    return Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Row(children: [
      for (final selector in _selectors()) ...[Expanded(child: selector), const SizedBox(width: 12)],
      Text(_count, style: const TextStyle(fontSize: 12)),
      IconButton(tooltip: 'Clear channel filters', onPressed: _active ? _clear : null, icon: const Icon(Icons.filter_alt_off)),
      if (model.filter == GuideFilter.recentlyWatched && onClearRecent != null)
        IconButton(tooltip: 'Clear recently watched channels', onPressed: onClearRecent, icon: const Icon(Icons.history_toggle_off)),
    ]));
  });
}
