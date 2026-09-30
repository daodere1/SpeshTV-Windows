import 'package:flutter/material.dart';

enum SpeshEpisodeFilter { all, unwatched, inProgress }

bool matchesEpisodeFilter(SpeshEpisodeFilter filter,
    {required bool played, required Duration position}) => switch (filter) {
  SpeshEpisodeFilter.all => true,
  SpeshEpisodeFilter.unwatched => !played,
  SpeshEpisodeFilter.inProgress => !played && position > Duration.zero,
};

class SpeshEpisodeFilters extends StatelessWidget {
  const SpeshEpisodeFilters({super.key, required this.selected,
    required this.onChanged, this.onJump});
  final SpeshEpisodeFilter selected;
  final ValueChanged<SpeshEpisodeFilter> onChanged;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center, children: [
      SegmentedButton<SpeshEpisodeFilter>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: SpeshEpisodeFilter.all, label: Text('All')),
          ButtonSegment(value: SpeshEpisodeFilter.unwatched, label: Text('Unwatched')),
          ButtonSegment(value: SpeshEpisodeFilter.inProgress, label: Text('In Progress')),
        ],
        selected: {selected}, onSelectionChanged: (value) => onChanged(value.single),
      ),
      TextButton.icon(onPressed: onJump, icon: const Icon(Icons.skip_next),
        label: const Text('Jump to Next Up')),
    ]);
}
