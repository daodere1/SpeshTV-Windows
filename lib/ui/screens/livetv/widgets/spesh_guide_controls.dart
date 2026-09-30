import 'package:flutter/material.dart';

class SpeshGuideControls extends StatelessWidget {
  const SpeshGuideControls({super.key, required this.searchController,
    required this.numberController, required this.onSearch, required this.onJump,
    required this.onHome, this.onPreview, this.onStop});

  final TextEditingController searchController;
  final TextEditingController numberController;
  final ValueChanged<String> onSearch;
  final VoidCallback onJump;
  final VoidCallback onHome;
  final VoidCallback? onPreview;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final preview = onStop != null
          ? IconButton(tooltip: 'Stop preview', onPressed: onStop,
              color: Colors.white70, padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(Icons.stop_circle_outlined))
          : SizedBox(width: 108, child: Tooltip(message: 'Watch preview',
              child: TextButton.icon(onPressed: onPreview,
                icon: const Icon(Icons.play_arrow), label: const Text('Preview'))));
      final search = SizedBox(
        width: compact ? constraints.maxWidth - (onStop != null ? 48 : 116) : 260,
        child: TextField(
          controller: searchController,
          onChanged: onSearch,
          decoration: InputDecoration(
            isDense: true, labelText: 'Search channels',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(tooltip: 'Clear channel search',
              color: Colors.white70,
              icon: const Icon(Icons.close), onPressed: () {
                searchController.clear(); onSearch('');
              }),
            border: const OutlineInputBorder(),
          ),
        ),
      );
      return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(message: 'Return to SpeshTV', child: TextButton.icon(
            onPressed: onHome, icon: const Icon(Icons.arrow_back),
            label: const Text('SpeshTV'))),
          if (!compact) search,
          SizedBox(width: compact ? 96 : 110, child: TextField(controller: numberController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => onJump(),
            decoration: const InputDecoration(isDense: true, labelText: 'Channel #',
              border: OutlineInputBorder()),
          )),
          IconButton(tooltip: 'Jump to channel', onPressed: onJump,
            color: Colors.white70, padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(Icons.arrow_forward)),
          if (!compact) preview,
          if (compact) search,
          if (compact) preview,
        ]);
    }),
  );
}
