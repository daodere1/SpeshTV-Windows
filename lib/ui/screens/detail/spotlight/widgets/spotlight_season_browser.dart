import 'package:flutter/material.dart';
import 'package:server_core/server_core.dart';

import '../../../../../data/models/aggregated_item.dart';
import '../../../../../preference/user_preferences.dart';
import 'spotlight_modal_grids.dart';
import 'spotlight_section_modal.dart';

/// A season picker and one virtualized episode viewport in the same modal.
/// Series DTOs are supplied by the authenticated detail view model, not fetched
/// again when switching seasons. Keeping the picker mounted preserves its view.
class SpotlightSeasonBrowser extends StatefulWidget {
  const SpotlightSeasonBrowser({
    super.key,
    required this.groups,
    required this.currentItemId,
    required this.currentSeason,
    required this.imageApi,
    required this.prefs,
    required this.seasonLabel,
    required this.onItemTap,
    this.onItemChanged,
  });
  final Map<int, List<AggregatedItem>> groups;
  final String currentItemId;
  final int? currentSeason;
  final ImageApi imageApi;
  final UserPreferences prefs;
  final String Function(int) seasonLabel;
  final ValueChanged<AggregatedItem> onItemTap;
  final VoidCallback? onItemChanged;
  @override
  State<SpotlightSeasonBrowser> createState() => _SpotlightSeasonBrowserState();
}

class _SpotlightSeasonBrowserState extends State<SpotlightSeasonBrowser> {
  int? _active;
  int? _selected;
  final _pickerNodes = <String, FocusNode>{};
  final _episodeFocus = FocusNode();
  SpotlightModalBackController? _backController;
  late final bool Function() _backCallback = _back;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SpotlightModalBackScope.maybeOf(context);
    if (controller == _backController) return;
    if (_backController?.handler == _backCallback)
      _backController?.handler = null;
    _backController = controller;
    controller?.handler = _backCallback;
  }

  bool _back() {
    if (!mounted || _active == null) return false;
    setState(() => _active = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pickerNodes['season_$_selected']?.requestFocus();
    });
    return true;
  }

  @override
  void dispose() {
    if (_backController?.handler == _backCallback)
      _backController?.handler = null;
    for (final node in _pickerNodes.values) {
      node.dispose();
    }
    _episodeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups.isEmpty)
      return const Center(child: Text('No episodes available.'));
    final numbers = groups.keys.toList()..sort();
    final seasons = [
      for (final number in numbers)
        AggregatedItem(
          id: 'season_$number',
          serverId: groups[number]!.first.serverId,
          rawData: {
            'Type': 'Season',
            'Name': widget.seasonLabel(number),
            'IndexNumber': number,
            'SpeshSeasonPicker': true,
            'PrimaryImageItemId': groups[number]!.first.seasonId,
            if (groups[number]!.first.rawData['SeasonPrimaryImageTag'] != null)
              'PrimaryImageTag':
                  groups[number]!.first.rawData['SeasonPrimaryImageTag'],
            'UserData': {'Played': groups[number]!.every((e) => e.isPlayed)},
          },
        ),
    ];
    for (final season in seasons) {
      _pickerNodes.putIfAbsent(season.id, () => FocusNode());
    }
    final active = _active;
    final episodes = groups[active] ?? const <AggregatedItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Choose a season'),
          )
        else
          Row(
            children: [
              BackButton(
                key: const ValueKey('episode_seasons_back'),
                onPressed: _back,
              ),
              Text(widget.seasonLabel(active)),
              const SizedBox(width: 12),
              Text('${episodes.length} episodes'),
            ],
          ),
        Expanded(
          child: Stack(
            children: [
              Offstage(
                offstage: active != null,
                child: ExcludeFocus(
                  excluding: active != null,
                  child: SpotlightMediaGridSection(
                    key: const ValueKey('season_picker'),
                    items: seasons,
                    imageApi: widget.imageApi,
                    prefs: widget.prefs,
                    bounded: true,
                    aspectRatio: 2 / 3,
                    requestInitialFocus: true,
                    currentItemId: 'season_${widget.currentSeason}',
                    itemFocusNodes: _pickerNodes,
                    onItemTap: (season) => setState(() {
                      _selected = season.indexNumber;
                      _active = season.indexNumber;
                    }),
                  ),
                ),
              ),
              if (active != null)
                SpotlightMediaGridSection(
                  key: ValueKey(
                    'season_episodes_${seasons.first.serverId}_$active',
                  ),
                  items: episodes,
                  imageApi: widget.imageApi,
                  prefs: widget.prefs,
                  bounded: true,
                  requestInitialFocus: true,
                  aspectRatio: 16 / 9,
                  landscapeCells: true,
                  firstFocusNode: _episodeFocus,
                  currentItemId:
                      episodes.any((e) => e.id == widget.currentItemId)
                      ? widget.currentItemId
                      : null,
                  onItemTap: widget.onItemTap,
                  onItemChanged: widget.onItemChanged,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
