import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/spotlight_cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime clock;
  late SpotlightCacheStore cache;
  const item = {
    'Id': 'one',
    'Name': 'A movie',
    'ImageTags': {'Logo': 'tag'},
    'BackdropImageTags': ['backdrop'],
    'ProductionYear': 2020,
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 9, 24);
    cache = SpotlightCacheStore(now: () => clock);
  });
  test('metadata survives a new cache instance', () async {
    await cache.write('server/user/settings', [item]);
    expect(
      await SpotlightCacheStore(now: () => clock).read('server/user/settings'),
      [item],
    );
  });
  test('another user, server or settings cannot reuse the selection', () async {
    await cache.write('server/user/settings', [item]);
    expect(await cache.read('server/other/settings'), isNull);
    expect(await cache.read('other/user/settings'), isNull);
    expect(await cache.read('server/user/changed'), isNull);
  });
  test('expired and future-dated records are ignored', () async {
    await cache.write('key', [item]);
    clock = clock.add(const Duration(hours: 7));
    expect(await cache.read('key'), isNull);
    clock = clock.subtract(const Duration(hours: 8));
    expect(await cache.read('key'), isNull);
  });
  test('credentials, paths and playback URLs are not saved', () async {
    await cache.write('key', [
      {
        ...item,
        'AccessToken': 'secret',
        'Path': '/private',
        'MediaSources': [
          {'Path': 'http://provider/user/password'},
        ],
        'RemoteTrailers': [
          {'Url': 'http://untrusted'},
        ],
      },
    ]);
    final raw = (await SharedPreferences.getInstance()).getString(
      SpotlightCacheStore.storageKey,
    )!;
    expect(raw, isNot(contains('secret')));
    expect(raw, isNot(contains('private')));
    expect(raw, isNot(contains('http://')));
    expect(await cache.read('key'), [item]);
  });
  test('corrupt storage is a cache miss', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SpotlightCacheStore.storageKey, '{bad json');
    expect(await cache.read('key'), isNull);
    await prefs.setString(
      SpotlightCacheStore.storageKey,
      jsonEncode({
        'key': 'key',
        'at': clock.millisecondsSinceEpoch,
        'items': [{}],
      }),
    );
    expect(await cache.read('key'), isNull);
  });
  test(
    'empty refresh does not destroy the last successful selection',
    () async {
      await cache.write('key', [item]);
      await cache.write('key', []);
      expect(await cache.read('key'), [item]);
    },
  );
  test('selection size is bounded', () async {
    await cache.write('key', List.filled(100, item));
    expect((await cache.read('key'))!.length, 30);
  });
}
