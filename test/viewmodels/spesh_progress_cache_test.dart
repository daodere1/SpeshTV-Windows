import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/home_row.dart';
import 'package:moonfin/data/repositories/multi_server_repository.dart';
import 'package:moonfin/data/services/progress_cache_store.dart';
import 'package:moonfin/data/services/row_data_source.dart';
import 'package:moonfin/data/viewmodels/media_bar_view_model.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Source extends Mock implements RowDataSource {}

class Client extends Mock implements MediaServerClient {}

class Bar extends Mock implements MediaBarViewModel {}

class Multi extends Mock implements MultiServerRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Source source;
  late HomeViewModel vm;
  late UserPreferences prefs;
  late String key;
  final cache = ProgressCacheStore();
  AggregatedItem card(String id, int position) => AggregatedItem(
    id: id,
    serverId: 'server',
    rawData: {
      'Name': id,
      'Type': 'Movie',
      'UserData': {'PlaybackPositionTicks': position, 'Played': false},
    },
  );
  HomeRow row(List<AggregatedItem> items) => HomeRow(
    id: 'resume',
    title: 'Progress',
    items: items,
    rowType: HomeRowType.resume,
    totalCount: items.length,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    await prefs.set(UserPreferences.enableMultiServerLibraries, false);
    await prefs.set(UserPreferences.mergeContinueWatchingNextUp, true);
    final client = Client();
    when(() => client.userId).thenReturn('user');
    when(() => client.baseUrl).thenReturn('server');
    source = Source();
    when(
      () => source.loadNextUp('server', startIndex: any(named: 'startIndex')),
    ).thenAnswer((_) async => row([]));
    vm = HomeViewModel(
      dataSource: source,
      prefs: prefs,
      client: client,
      mediaBarViewModel: Bar(),
      multiServerRepo: Multi(),
    );
    key = jsonEncode([
      'local-first-activity-v2',
      'server',
      'user',
      prefs.get(UserPreferences.homeSectionsJson),
      prefs.get(UserPreferences.hiddenContinueWatchingItems),
      prefs.get(UserPreferences.hiddenNextUpSeries),
      prefs.get(UserPreferences.blockedParentalRatings),
    ]);
  });
  tearDown(() => vm.dispose());
  test('known activity precedes Next Up without activity dates', () async {
    final old = card('old-resume', 90);
    old.rawData['UserData']['LastPlayedDate'] = '2026-09-01T00:00:00Z';
    when(() => source.loadResume('server', startIndex: any(named: 'startIndex')))
        .thenAnswer((_) async => row([old]));
    when(() => source.loadNextUp('server', startIndex: any(named: 'startIndex')))
        .thenAnswer((_) async => row([card('Black Clover', 0), card('second-next', 0)]));
    await vm.refreshResumeAndNextUp();
    expect(vm.rows.single.items.map((i) => i.id),
          ['old-resume', 'Black Clover', 'second-next']);
  });
  test('cold Home displays resume while Next Up is still pending', () async {
    final slow = Completer<HomeRow>();
    final visible = Completer<void>();
    when(() => source.loadResume('server', startIndex: any(named: 'startIndex')))
        .thenAnswer((_) async => row([card('fast', 90)]));
    when(() => source.loadNextUp('server', startIndex: any(named: 'startIndex')))
        .thenAnswer((_) => slow.future);
    vm.addListener(() {
      if (!visible.isCompleted && vm.rows.any((r) => r.items.any((i) => i.id == 'fast'))) {
        visible.complete();
      }
    });
    final loading = vm.refreshResumeAndNextUp();
    await visible.future;
    expect(vm.rows.single.items.single.id, 'fast');
    slow.complete(row([card('later', 0)]));
    await loading;
    expect(vm.rows.single.items.map((i) => i.id), containsAll(['fast', 'later']));
  });
  test(
    'cold Home never displays disk progress before a fresh server response',
    () async {
      await cache.write(key, ProgressSnapshot([card('movie', 20)], false));
      final response = Completer<HomeRow>();
      final requested = Completer<void>();
      when(
        () => source.loadResume('server', startIndex: any(named: 'startIndex')),
      ).thenAnswer((_) {
        requested.complete();
        return response.future;
      });
      final loading = vm.refreshResumeAndNextUp();
      await requested.future;
      expect(vm.rows.expand((r) => r.items), isEmpty);
      response.complete(row([card('movie', 90)]));
      await loading;
      expect(vm.rows.single.items.single.playbackPositionTicks, 90);
      expect((await cache.read(key))!.items.single.playbackPositionTicks, 90);
    },
  );
  test(
    'cold failure does not display disk history; new progress appears after recovery',
    () async {
      await cache.write(key, ProgressSnapshot([card('movie', 20)], false));
      when(
        () => source.loadResume('server', startIndex: any(named: 'startIndex')),
      ).thenAnswer((_) async => throw StateError('offline'));
      await vm.refreshResumeAndNextUp();
      expect(vm.rows, isEmpty);
      when(
        () => source.loadResume('server', startIndex: any(named: 'startIndex')),
      ).thenAnswer((_) async => row([]));
      await vm.refreshResumeAndNextUp();
      expect(vm.rows, isEmpty);
      expect((await cache.read(key))!.items, isEmpty);
      when(
        () => source.loadResume('server', startIndex: any(named: 'startIndex')),
      ).thenAnswer((_) async => row([card('new', 10)]));
      await vm.refreshResumeAndNextUp();
      expect(vm.rows.single.items.single.id, 'new');
    },
  );
  test(
    'invalidation automatically retries an old request without another refresh call',
    () async {
      final response = Completer<HomeRow>();
      final requested = Completer<void>();
      var requests = 0;
      when(
        () => source.loadResume('server', startIndex: any(named: 'startIndex')),
      ).thenAnswer((_) {
        if (requests++ == 0) {
          requested.complete();
          return response.future;
        }
        return Future.value(row([card('new', 90)]));
      });
      final loading = vm.refreshResumeAndNextUp();
      await requested.future;
      vm.invalidateProgressCache();
      response.complete(row([card('old', 20)]));
      await loading;
      expect(vm.rows.single.items.single.id, 'new');
      expect((await cache.read(key))!.items.single.id, 'new');
      expect(requests, 2);
    },
  );
}
