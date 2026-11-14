import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/media_bar_slide_item.dart';
import 'package:moonfin/data/models/media_bar_state.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/repositories/media_bar_repository.dart';
import 'package:moonfin/data/viewmodels/media_bar_view_model.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Repo extends Mock implements MediaBarRepository {}

class Ratings extends Mock implements MdbListRepository {}

class Client extends Mock implements MediaServerClient {}

MediaBarReady ready(String id) => MediaBarReady([
  MediaBarSlideItem(itemId: id, serverId: 'server', title: id),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repo repo;
  late MediaBarViewModel vm;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);
    await prefs.set(UserPreferences.enableAdditionalRatings, false);
    repo = Repo();
    vm = MediaBarViewModel(repo, Ratings(), prefs, Client());
  });
  test('cached Spotlight renders before network and refreshes later', () async {
    final response = Completer<MediaBarState>();
    when(() => repo.loadItems(onCached: any(named: 'onCached'))).thenAnswer((
      call,
    ) {
      (call.namedArguments[#onCached] as void Function(MediaBarReady))(
        ready('cached'),
      );
      return response.future;
    });
    final loading = vm.load();
    expect(vm.items.single.itemId, 'cached');
    response.complete(ready('fresh'));
    await loading;
    expect(vm.items.single.itemId, 'fresh');
    vm.dispose();
  });
  test('refresh error retains cached Spotlight', () async {
    when(() => repo.loadItems(onCached: any(named: 'onCached'))).thenAnswer((
      call,
    ) async {
      (call.namedArguments[#onCached] as void Function(MediaBarReady))(
        ready('cached'),
      );
      return const MediaBarError('offline');
    });
    await vm.load();
    expect(vm.items.single.itemId, 'cached');
    vm.dispose();
  });
  test('older forced refresh cannot replace newer results', () async {
    final old = Completer<MediaBarState>();
    var calls = 0;
    when(() => repo.loadItems(onCached: any(named: 'onCached'))).thenAnswer((
      _,
    ) {
      return calls++ == 0 ? old.future : Future.value(ready('new settings'));
    });
    final first = vm.load();
    await vm.load(force: true, preserveCurrent: false);
    old.complete(ready('old settings'));
    await first;
    await pumpEventQueue();
    expect(vm.items.single.itemId, 'new settings');
    vm.dispose();
  });
  test('repeated Home refresh does not duplicate an in-flight query', () async {
    final response = Completer<MediaBarState>();
    when(() => repo.loadItems(onCached: any(named: 'onCached')))
        .thenAnswer((_) => response.future);
    final first = vm.load();
    await vm.load(force: true);
    verify(() => repo.loadItems(onCached: any(named: 'onCached'))).called(1);
    response.complete(ready('fresh'));
    await first;
    vm.dispose();
  });
  test('a disposed view ignores in-flight responses', () async {
    final response = Completer<MediaBarState>();
    when(
      () => repo.loadItems(onCached: any(named: 'onCached')),
    ).thenAnswer((_) => response.future);
    final loading = vm.load();
    vm.dispose();
    response.complete(ready('too late'));
    await loading;
    expect(vm.state, isA<MediaBarLoading>());
  });
}
