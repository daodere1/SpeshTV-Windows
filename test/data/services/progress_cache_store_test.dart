import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/progress_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 24);
  late ProgressCacheStore cache;
  AggregatedItem card(String id) => AggregatedItem(
    id: id,
    serverId: 'server',
    rawData: {
      'Name': 'Episode',
      'Type': 'Episode',
      'SeriesId': 'series',
      'SeriesName': 'Show',
      'SpeshProgressFeed': 'resume',
      'ImageTags': {'Primary': 'image-tag'},
      'UserData': {
        'PlaybackPositionTicks': 200000000,
        'Played': false,
        'LastPlayedDate': now.toIso8601String(),
        'Secret': 'not-stored',
      },
      'Path': 'https://provider/secret',
      'AccessToken': 'secret',
      'MediaSources': [
        {'Path': 'https://provider/secret'},
      ],
    },
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = ProgressCacheStore(now: () => now);
  });
  test('new instance restores progress, artwork and source tags', () async {
    await cache.write(
      'server/user/settings',
      ProgressSnapshot([card('one')], true),
    );
    final restored = await ProgressCacheStore(
      now: () => now,
    ).read('server/user/settings');
    expect(restored!.hasMore, true);
    expect(restored.items.single.playbackPositionTicks, 200000000);
    expect(restored.items.single.isPlayed, false);
    expect(restored.items.single.rawData['ImageTags'], {
      'Primary': 'image-tag',
    });
    expect(restored.items.single.rawData['SpeshProgressFeed'], 'resume');
  });
  test(
    'scope mismatch does not disclose another user or server snapshot',
    () async {
      await cache.write(
        'server/user/settings',
        ProgressSnapshot([card('one')], false),
      );
      for (final key in [
        'server/other/settings',
        'other/user/settings',
        'server/user/new-settings',
      ]) {
        expect(await cache.read(key), isNull);
      }
    },
  );
  test('expired and future-dated snapshots are ignored', () async {
    await cache.write('key', ProgressSnapshot([card('one')], false));
    expect(
      await ProgressCacheStore(
        now: () => now.add(const Duration(minutes: 3)),
      ).read('key'),
      isNull,
    );
    expect(
      await ProgressCacheStore(
        now: () => now.subtract(const Duration(seconds: 1)),
      ).read('key'),
      isNull,
    );
  });
  test(
    'storage excludes credentials, source paths and private user fields',
    () async {
      await cache.write('key', ProgressSnapshot([card('one')], false));
      final raw = (await SharedPreferences.getInstance()).getString(
        ProgressCacheStore.storageKey,
      )!;
      expect(raw, isNot(contains('secret')));
      expect(raw, isNot(contains('MediaSources')));
      expect(raw, isNot(contains('Secret')));
    },
  );
  test('successful empty result replaces completed cards', () async {
    await cache.write('key', ProgressSnapshot([card('one')], false));
    await cache.write('key', const ProgressSnapshot([], false));
    expect((await cache.read('key'))!.items, isEmpty);
  });
  test('bounded snapshot advertises remaining items', () async {
    await cache.write(
      'key',
      ProgressSnapshot(List.generate(70, (i) => card('$i')), false),
    );
    final restored = (await cache.read('key'))!;
    expect(restored.items.length, 60);
    expect(restored.hasMore, true);
  });
  test('invalidation is scoped and ordered after outstanding writes', () async {
    final write = cache.write('key', ProgressSnapshot([card('one')], false));
    final invalidate = cache.invalidate('key');
    await Future.wait([write, invalidate]);
    expect(await cache.read('key'), isNull);
    await cache.write('key', ProgressSnapshot([card('two')], false));
    await cache.invalidate('other-user');
    expect((await cache.read('key'))!.items.single.id, 'two');
  });
  test('malformed payloads are harmless misses', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in [
      '{',
      '[]',
      jsonEncode({
        'key': 'key',
        'at': now.millisecondsSinceEpoch,
        'hasMore': false,
        'items': [
          {
            'data': {'Name': 1},
          },
        ],
      }),
    ]) {
      await prefs.setString(ProgressCacheStore.storageKey, raw);
      expect(await cache.read('key'), isNull);
    }
  });
}
