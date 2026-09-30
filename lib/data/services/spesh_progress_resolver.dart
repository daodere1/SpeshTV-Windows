import 'package:server_core/server_core.dart';

import '../models/aggregated_item.dart';
import '../models/search_source.dart';
import '../models/home_row.dart';
import '../utils/bounded_concurrency.dart';

class ProgressIdentity {
  final AggregatedItem entity;
  final String source;
  const ProgressIdentity(this.entity, this.source);
}

AggregatedItem _normalized(AggregatedItem item) => AggregatedItem(
  id: item.id,
  serverId: item.serverId,
  rawData: {
    ...item.rawData,
    'Name': item.name
        .replaceAll(
          RegExp(
            r'\s*\((?:english|spanish|french|german|italian|portuguese|chinese|mandarin|cantonese|japanese|korean|hindi|multi(?: audio)?)\)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s*\(\d{4}(?:\s*-\s*\d{4})?\)\s*$'), '')
        .trim(),
  },
);

bool sameProgressEntity(AggregatedItem a, AggregatedItem b) =>
    sameSearchTitle(_normalized(a), _normalized(b));

/// Per-view-model, signed-in-user metadata cache. Never writes watch history.
class SpeshProgressResolver {
  SpeshProgressResolver(this.client);
  final MediaServerClient client;
  final _descriptions = <String, Future<ProgressIdentity>>{};
  final _localMatches = <String, Future<bool>>{};
  Future<Map<String, String>>? _views;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  String? _user;

  void invalidate() {
    _descriptions.clear();
    _localMatches.clear();
    _views = null;
    _expires = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _checkCache() {
    if (_user != client.userId ||
        DateTime.now().isAfter(_expires) ||
        _descriptions.length > 512) {
      _user = client.userId;
      _expires = DateTime.now().add(const Duration(minutes: 10));
      _views = null;
      _descriptions.clear();
      _localMatches.clear();
    }
  }

  Future<Map<String, String>> _libraries() => _views ??= () async {
    try {
      final response = await client.userViewsApi.getUserViews();
      return {
        for (final item in (response['Items'] as List? ?? []).whereType<Map>())
          if (item['Id'] != null &&
              const [
                'movies',
                'tvshows',
                '',
              ].contains(item['CollectionType'] ?? ''))
            item['Id'].toString(): isVodLibrary(item['Name']?.toString() ?? '')
                ? 'vod'
                : 'local',
      };
    } catch (_) {
      _views = null;
      rethrow;
    }
  }();

  Future<ProgressIdentity> describe(AggregatedItem item) {
    final id = item.type == 'Episode' ? item.seriesId : item.id;
    if (id == null || id.isEmpty) {
      return Future.value(ProgressIdentity(item, 'unknown'));
    }
    final key = '${item.serverId}:$id';
    return _descriptions.putIfAbsent(key, () async {
      try {
        final raw = item.type == 'Movie' && item.rawData['ProviderIds'] is Map
            ? item.rawData
            : await client.itemsApi.getItem(
                id,
                fields: 'ProviderIds,ProductionYear,Type',
              );
        final entity = AggregatedItem(
          id: id,
          serverId: item.serverId,
          rawData: raw,
        );
        final views = await _libraries();
        final ancestors = await client.itemsApi.getAncestors(id);
        final sources = [
          raw,
          ...ancestors,
        ].map((p) => views[p['Id']?.toString()]).whereType<String>();
        return ProgressIdentity(
          entity,
          sources.isEmpty ? 'unknown' : sources.first,
        );
      } catch (_) {
        _descriptions.remove(key);
        rethrow;
      }
    });
  }

  Future<bool> _localExists(ProgressIdentity description) {
    final entity = description.entity;
    final key = '${entity.serverId}:${entity.id}';
    return _localMatches.putIfAbsent(key, () async {
      try {
        if (!const ['Movie', 'Series'].contains(entity.type) ||
            entity.name.isEmpty) {
          return false;
        }
        final views = await _libraries();
        if (!views.values.contains('local')) return false;
        final ids = entity.providerIds.entries.where(
          (e) =>
              const ['tmdb', 'imdb', 'tvdb'].contains(e.key.toLowerCase()) &&
              RegExp(r'^(?:tt)?\d+$').hasMatch(e.value),
        );
        final providerFilter = ids.map((e) => '${e.key}.${e.value}').join(',');
        // Search only accessible local libraries. A global query scans VOD too,
        // then needs extra ancestry lookups to discard those same VOD matches.
        for (final byId in [if (providerFilter.isNotEmpty) true, false]) {
          for (final library in views.entries.where(
            (entry) => entry.value == 'local',
          )) {
            final response = await client.itemsApi.getItems(
              parentId: library.key,
              recursive: true,
              includeItemTypes: [entity.type!],
              limit: 50,
              anyProviderIdEquals: byId ? providerFilter : null,
              searchTerm: byId ? null : _normalized(entity).name,
              fields: 'ProviderIds,ProductionYear,Type',
              collapseBoxSetItems: false,
              enableTotalRecordCount: false,
            );
            for (final raw
                in (response['Items'] as List? ?? []).whereType<Map>()) {
              final id = raw['Id']?.toString() ?? '';
              if (id.isEmpty || id == entity.id) continue;
              final candidate = AggregatedItem(
                id: id,
                serverId: entity.serverId,
                rawData: Map<String, dynamic>.from(raw),
              );
              if (!sameProgressEntity(entity, candidate)) continue;
              return true; // ParentId scoped this result to a local library.
            }
          }
        }
        return false;
      } catch (_) {
        _localMatches.remove(key);
        rethrow;
      }
    });
  }

  Future<List<AggregatedItem>> resolve(List<AggregatedItem> items) async {
    _checkCache();
    final descriptions = await mapBounded<AggregatedItem, ProgressIdentity>(
      items,
      3,
      (item) async {
        try {
          return await describe(item).timeout(const Duration(seconds: 4));
        } catch (_) {
          return ProgressIdentity(item, 'unknown');
        }
      },
    );
    final hidden = await mapBounded<int, bool>(
      List.generate(items.length, (i) => i),
      3,
      (i) async {
        final description = descriptions[i]!;
        if (description.source != 'vod') return false;
        if (descriptions.any(
          (other) =>
              other?.source == 'local' &&
              sameProgressEntity(description.entity, other!.entity),
        )) {
          return true;
        }
        try {
          return await _localExists(description).timeout(const Duration(seconds: 4));
        } catch (_) {
          return false;
        } // A failed lookup must not hide an unconfirmed title.
      },
    );
    final groups = <List<int>>[];
    for (var i = 0; i < items.length; i++) {
      if (hidden[i] == true) continue;
      final index = groups.indexWhere(
        (group) => group.every(
          (j) => sameProgressEntity(
            descriptions[i]!.entity,
            descriptions[j]!.entity,
          ),
        ),
      );
      if (index < 0) {
        groups.add([i]);
      } else {
        groups[index].add(i);
      }
    }
    return groups.map((group) {
      final local = group
          .where((i) => descriptions[i]!.source == 'local')
          .toList();
      final choices = local.isEmpty ? group : local;
      final index = choices.firstWhere(
        (i) => items[i].rawData['SpeshProgressFeed'] == 'resume',
        orElse: () => choices.first,
      );
      return items[index];
    }).toList();
  }
}

/// Source offsets count raw results, never the smaller deduplicated row.
class SpeshProgressFeed {
  SpeshProgressFeed({
    required this.resolve,
    required this.resume,
    required this.nextUp,
    required this.filterResume,
    required this.filterNextUp,
  });
  final Future<List<AggregatedItem>> Function(List<AggregatedItem>) resolve;
  final Future<HomeRow> Function(int) resume, nextUp;
  final List<AggregatedItem> Function(List<AggregatedItem>) filterResume,
      filterNextUp;
  final _raw = <String, AggregatedItem>{};
  final _offsets = [0, 0];
  final _done = [false, false];
  List<AggregatedItem> _visible = [];
  int _generation = 0;
  void invalidate() => _generation++;

  Future<({List<AggregatedItem> items, bool hasMore, bool complete})?> load({
    bool refresh = false,
    void Function(List<AggregatedItem> items, bool hasMore)? onPartial,
  }) async {
    if (refresh) {
      invalidate();
      _raw.clear();
      _visible = [];
      _offsets.fillRange(0, 2, 0);
      _done.fillRange(0, 2, false);
    }
    final generation = _generation;
    var complete = true;
    final target = _visible.length + 15;
    // Backfill duplicate-only pages, bounded to keep a large catalog from monopolizing Home.
    for (
      var batch = 0;
      batch < 5 && _visible.length < target && !_done.every((v) => v);
      batch++
    ) {
      Future<HomeRow?> read(int source) async {
        if (_done[source]) return null;
        try {
          return await (source == 0 ? resume : nextUp)(
            _offsets[source],
          ).timeout(const Duration(seconds: 35));
        } catch (_) {
          return null;
        }
      }

      // Serialize merges, not network requests: either source can render first.
      Future<void> merges = Future.value();
      final pages = await Future.wait(List.generate(2, (source) async {
        final page = await read(source);
        if (page != null) {
          merges = merges.then((_) async {
            if (generation != _generation) return;
            for (final item in (source == 0 ? filterResume : filterNextUp)(page.items)) {
              final key = '${item.serverId}:${item.id}';
              if (source == 0 || !_raw.containsKey(key)) {
                _raw[key] = AggregatedItem(id: item.id, serverId: item.serverId,
                  rawData: {...item.rawData, 'SpeshProgressFeed': source == 0 ? 'resume' : 'nextUp'});
              }
            }
            final resolved = await resolve(_raw.values.toList());
            if (generation != _generation) return;
            _visible = resolved;
            if (resolved.isNotEmpty) onPartial?.call(List.of(resolved), true);
          });
        }
        return page;
      }));
      await merges;
      if (generation != _generation) return null;
      if (pages.every((p) => p == null)) return null;
      for (var source = 0; source < 2; source++) {
        final page = pages[source];
        if (page == null) {
          if (!_done[source]) complete = false;
          continue; // Retry this source at its unchanged offset later.
        }
        _offsets[source] += page.items.length;
        _done[source] =
            page.items.isEmpty ||
            (page.totalCount > 0
                ? _offsets[source] >= page.totalCount
                : page.items.length < 15);
      }
      if (List.generate(
        2,
        (i) => i,
      ).any((i) => pages[i] == null && !_done[i])) {
        break;
      }
    }
    return (
      items: List.of(_visible),
      hasMore: !_done.every((v) => v),
      complete: complete,
    );
  }
}
