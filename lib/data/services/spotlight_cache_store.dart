import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Single-slot, user/config-scoped metadata cache. Image URLs are regenerated
/// with the current client; credentials and playback URLs are never persisted.
class SpotlightCacheStore {
  static const storageKey = 'speshtv_spotlight_v1';
  static const maxAge = Duration(hours: 6);
  final DateTime Function() now;
  SpotlightCacheStore({DateTime Function()? now}) : now = now ?? DateTime.now;

  static const _fields = {
    'Id',
    'ServerId',
    'Name',
    'Type',
    'Overview',
    'ProductionYear',
    'OfficialRating',
    'CommunityRating',
    'CriticRating',
    'Genres',
    'RunTimeTicks',
    'ProviderIds',
    'ImageTags',
    'BackdropImageTags',
  };

  Future<List<Map<String, dynamic>>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map || data['key'] != key || data['at'] is! int) return null;
      final age = now().millisecondsSinceEpoch - (data['at'] as int);
      if (age < 0 || age > maxAge.inMilliseconds) return null;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      if (items.isEmpty ||
          items.length > 30 ||
          items.any(
            (item) => item['Id'] is! String || item['Name'] is! String,
          )) {
        return null;
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    try {
      final payload = jsonEncode({
        'key': key,
        'at': now().millisecondsSinceEpoch,
        'items': items
            .take(30)
            .map(
              (item) => {
                for (final field in _fields)
                  if (item.containsKey(field)) field: item[field],
              },
            )
            .toList(),
      });
      if (payload.length > 256 * 1024) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, payload);
    } catch (_) {
      // Storage may be unavailable or full; live loading still works.
    }
  }
}
