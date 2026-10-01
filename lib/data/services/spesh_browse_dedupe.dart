import '../models/aggregated_item.dart';
import '../models/search_source.dart';
import '../utils/bounded_concurrency.dart';

String? _language(AggregatedItem item) => RegExp(
  r'\((english|spanish|french|german|italian|portuguese|chinese|mandarin|cantonese|japanese|korean|hindi)\)\s*$',
  caseSensitive: false,
).firstMatch(item.name)?.group(1)?.toLowerCase();

bool _sameEdition(AggregatedItem a, AggregatedItem b) {
  if (a.productionYear != null && b.productionYear != null &&
      a.productionYear != b.productionYear) return false;
  final left = _language(a);
  final right = _language(b);
  if (left != null && right != null && left != right) return false;
  return sameSearchTitle(a, b);
}

Iterable<String> _keys(AggregatedItem item) sync* {
  final prefix = '${item.serverId}:${item.type}:';
  if (item.productionYear != null) {
    yield '${prefix}title:${item.productionYear}:${searchIdentityTitle(item.name)}';
  }
  for (final entry in item.providerIds.entries) {
    final key = entry.key.toLowerCase();
    if (const {'tmdb', 'tvdb', 'imdb'}.contains(key) && entry.value.trim().isNotEmpty) {
      yield '$prefix$key:${entry.value.trim().toLowerCase()}';
    }
  }
}

/// Dedupe only confirmed local/VOD pairs, preserving order and unknown sources.
Future<List<AggregatedItem>> preferLocalBrowseItems(
  List<AggregatedItem> items,
  Future<String> Function(AggregatedItem) source,
) async {
  final groups = <List<AggregatedItem>>[];
  final index = <String, Set<int>>{};
  for (final item in items) {
    if (!const {'Movie', 'Series', 'MusicVideo'}.contains(item.type)) {
      groups.add([item]);
      continue;
    }
    final keys = _keys(item).toList();
    final candidates = <int>{for (final key in keys) ...?index[key]};
    final match = candidates.where(
      (i) => groups[i].every((other) => _sameEdition(other, item)),
    ).firstOrNull;
    final group = match ?? groups.length;
    if (match == null) {
      groups.add([item]);
    } else {
      groups[group].add(item);
    }
    for (final key in keys) {
      index.putIfAbsent(key, () => {}).add(group);
    }
  }
  final resolved = await mapBounded<List<AggregatedItem>, List<AggregatedItem>>(
    groups, 3, (group) async {
      if (group.length < 2) return group;
      final sources = <String>[];
      for (final item in group) {
        try {
          sources.add(await source(item).timeout(const Duration(seconds: 2)));
        } catch (_) {
          sources.add('unknown');
        }
      }
      if (!sources.contains('local')) return group;
      return [for (var i = 0; i < group.length; i++)
        if (sources[i] != 'vod') group[i]];
    },
  );
  final replacements = <AggregatedItem, List<AggregatedItem>>{};
  for (var i = 0; i < groups.length; i++) {
    final kept = resolved[i] ?? groups[i];
    if (kept.length == groups[i].length) continue;
    replacements[groups[i].first] = kept;
    for (final item in groups[i].skip(1)) {
      replacements[item] = const [];
    }
  }
  return [for (final item in items) ...replacements[item] ?? [item]];
}
