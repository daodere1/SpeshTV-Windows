import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_item.dart';

class ProgressSnapshot {
  final List<AggregatedItem> items;
  final bool hasMore;
  const ProgressSnapshot(this.items, this.hasMore);
}

/// A bounded, single-slot browser snapshot. Mutations are ordered so a server
/// invalidation cannot be undone by a storage write already in flight.
class ProgressCacheStore {
  static const storageKey = 'speshtv_progress_v1';
  static const maxAge = Duration(minutes: 30);
  static Future<void> _writes = Future.value();
  final DateTime Function() now;
  ProgressCacheStore({DateTime Function()? now}) : now = now ?? DateTime.now;

  static const _fields = {
    'Name',
    'Type',
    'SeriesId',
    'SeriesName',
    'SeasonId',
    'ParentId',
    'IndexNumber',
    'ParentIndexNumber',
    'ProductionYear',
    'RunTimeTicks',
    'Overview',
    'OfficialRating',
    'CommunityRating',
    'CriticRating',
    'Genres',
    'ImageTags',
    'BackdropImageTags',
    'PrimaryImageAspectRatio',
    'PrimaryImageTag',
    'PrimaryImageItemId',
    'SeriesPrimaryImageTag',
    'SeriesThumbImageTag',
    'ParentPrimaryImageTag',
    'ParentPrimaryImageItemId',
    'ParentThumbItemId',
    'ParentThumbImageTag',
    'ParentBackdropItemId',
    'ParentBackdropImageTags',
    'ParentLogoItemId',
    'ParentLogoImageTag',
    'SpeshProgressFeed',
  };
  static const _userFields = {
    'Played',
    'PlayedPercentage',
    'PlaybackPositionTicks',
    'LastPlayedDate',
    'PlayCount',
    'IsFavorite',
    'UnplayedItemCount',
  };

  Future<ProgressSnapshot?> read(String key) async {
    await _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.length > 512 * 1024) return null;
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['key'] != key ||
          data['at'] is! int ||
          data['hasMore'] is! bool ||
          data['items'] is! List) {
        return null;
      }
      final age = now().millisecondsSinceEpoch - (data['at'] as int);
      if (age < 0 || age > maxAge.inMilliseconds) return null;
      final entries = data['items'] as List;
      if (entries.length > 60) return null;
      final items = entries.map((entry) {
        final raw = Map<String, dynamic>.from(entry['data'] as Map);
        if (raw['Name'] is! String ||
            !const ['Movie', 'Episode'].contains(raw['Type']) ||
            entry['id'] is! String ||
            (entry['id'] as String).isEmpty ||
            entry['server'] is! String) {
          throw const FormatException('Invalid progress card');
        }
        return AggregatedItem(
          id: entry['id'],
          serverId: entry['server'],
          rawData: raw,
        );
      }).toList();
      return ProgressSnapshot(items, data['hasMore']);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, ProgressSnapshot snapshot) =>
      _mutate(() async {
        final items = snapshot.items
            .take(60)
            .map(
              (item) => {
                'id': item.id,
                'server': item.serverId,
                'data': {
                  for (final field in _fields)
                    if (item.rawData.containsKey(field))
                      field: item.rawData[field],
                  'UserData': {
                    for (final field in _userFields)
                      if ((item.rawData['UserData'] as Map? ?? {}).containsKey(
                        field,
                      ))
                        field: item.rawData['UserData'][field],
                  },
                },
              },
            )
            .toList();
        final payload = jsonEncode({
          'key': key,
          'at': now().millisecondsSinceEpoch,
          'hasMore': snapshot.hasMore || snapshot.items.length > 60,
          'items': items,
        });
        if (payload.length > 512 * 1024) return;
        await (await SharedPreferences.getInstance()).setString(
          storageKey,
          payload,
        );
      });

  Future<void> invalidate(String key) => _mutate(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && (jsonDecode(raw) as Map)['key'] == key) {
      await prefs.remove(storageKey);
    }
  });

  Future<void> _mutate(Future<void> Function() action) {
    _writes = _writes.then((_) async {
      try {
        await action();
      } catch (_) {
        /* Cache failure must not block Home. */
      }
    });
    return _writes;
  }
}
