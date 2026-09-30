import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/viewmodels/live_tv_guide_view_model.dart';
import 'package:server_core/server_core.dart';

class _MockClient extends Mock implements MediaServerClient {}

class _MockLiveTvApi extends Mock implements LiveTvApi {}

Map<String, dynamic> _channel(String id) => {'Id': id, 'Name': 'Ch $id'};

void main() {
  late _MockClient client;
  late _MockLiveTvApi liveTv;

  setUp(() {
    client = _MockClient();
    liveTv = _MockLiveTvApi();
    when(() => client.liveTvApi).thenReturn(liveTv);
    when(() => client.userId).thenReturn('user');
    when(
      () => liveTv.getGuide(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        channelIds: any(named: 'channelIds'),
        fields: any(named: 'fields'),
        enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
        enableImages: any(named: 'enableImages'),
        enableUserData: any(named: 'enableUserData'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => {'Items': <dynamic>[]});
  });

  test(
    'load() fetches only the first batch; loadMorePrograms() paginates the rest',
    () async {
      // 120 channels → batches of 50 (never one giant all-channels request).
      final channels = List.generate(120, (i) => _channel('c$i'));
      when(
        () => liveTv.getChannels(
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
          fields: any(named: 'fields'),
          enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => {'Items': channels});

      final vm = LiveTvGuideViewModel(client);
      await vm.load();

      // Initial load requested exactly one batch of 50 channels, not all 120.
      final captured = verify(
        () => liveTv.getGuide(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          channelIds: captureAny(named: 'channelIds'),
          fields: any(named: 'fields'),
          enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
          enableImages: any(named: 'enableImages'),
          enableUserData: any(named: 'enableUserData'),
          userId: any(named: 'userId'),
        ),
      ).captured;
      expect(captured.length, 1);
      expect((captured.single as List).length, 50);
      expect(vm.programsHighWater, 50);
      expect(vm.hasMorePrograms, isTrue);

      await vm.loadMorePrograms();
      expect(vm.programsHighWater, 100);
      expect(vm.hasMorePrograms, isTrue);

      await vm.loadMorePrograms();
      expect(vm.programsHighWater, 120);
      expect(vm.hasMorePrograms, isFalse);

      // Further calls are no-ops once every channel has been requested.
      await vm.loadMorePrograms();
      expect(vm.programsHighWater, 120);
    },
  );

  test('picker Now Next ignores genre filtering but preserves true schedule', () async {
    final now = DateTime.now();
    when(() => liveTv.getChannels(
      sortBy: any(named: 'sortBy'), sortOrder: any(named: 'sortOrder'),
      fields: any(named: 'fields'), enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
      userId: any(named: 'userId'),
    )).thenAnswer((_) async => {'Items': [_channel('a')]});
    when(() => liveTv.getGuide(
      startDate: any(named: 'startDate'), endDate: any(named: 'endDate'),
      channelIds: any(named: 'channelIds'), fields: any(named: 'fields'),
      enableTotalRecordCount: any(named: 'enableTotalRecordCount'), enableImages: any(named: 'enableImages'),
      enableUserData: any(named: 'enableUserData'), userId: any(named: 'userId'),
    )).thenAnswer((_) async => {'Items': [
      {'Id': 'current', 'ChannelId': 'a', 'Name': 'Live sport', 'IsSports': true,
        'StartDate': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'EndDate': now.add(const Duration(minutes: 10)).toIso8601String()},
      {'Id': 'next', 'ChannelId': 'a', 'Name': 'News', 'IsNews': true,
        'StartDate': now.add(const Duration(minutes: 10)).toIso8601String(),
        'EndDate': now.add(const Duration(minutes: 40)).toIso8601String()},
    ]});
    final vm = LiveTvGuideViewModel(client);
    await vm.load();
    vm.setFilter(GuideFilter.sports);
    expect(vm.nowNextForChannel('a').next, isNull);
    final schedule = vm.nowNextForChannel('a', ignoreGenreFilter: true);
    expect(schedule.now?.name, 'Live sport');
    expect(schedule.next?.name, 'News');
    vm.dispose();
  });

  test('channel tags filter the whole lineup without programme listings', () async {
    final channels = List.generate(120, (i) => {
      ..._channel('c$i'), 'Name': i == 119 ? 'PR | WAPA' : 'Station $i',
      'ChannelNumber': '${i + 1}',
      'Tags': i == 118 ? ['US| NBA PACKAGE', 'Sports'] : i == 119 ? ['PR | Puerto Rico', 'Local'] : ['General'],
      'UserData': {'IsFavorite': i == 119},
    });
    when(() => liveTv.getChannels(
      sortBy: any(named: 'sortBy'), sortOrder: any(named: 'sortOrder'),
      fields: 'ImageTags,UserData,Tags,Genres', enableTotalRecordCount: false,
      userId: 'user',
    )).thenAnswer((_) async => {'Items': channels});
    final vm = LiveTvGuideViewModel(client);
    await vm.load();
    vm.setChannelFilters(country: 'PR | Puerto Rico');
    await Future<void>.delayed(Duration.zero);
    expect(vm.filteredChannels.single.id, 'c119');
    expect(vm.hasProgramsFor('c119'), true);
    expect(vm.programsHighWater, 50);
    vm.setFilter(GuideFilter.favorites);
    expect(vm.filteredChannels.single.id, 'c119');
    vm.setChannelFilters(tag: 'Sports');
    expect(vm.filteredChannels, isEmpty);
    expect(vm.activeChannelFilterCount, 3);
    vm.clearBrowseFilters();
    expect(vm.activeChannelFilterCount, 0);
    expect(vm.filter, GuideFilter.all);
    expect(vm.filteredChannels.length, 120);
    vm.setFilter(GuideFilter.all);
    vm.setChannelFilters(country: '', package: 'NBA');
    expect(vm.filteredChannels.single.id, 'c118');
    expect(vm.channelForNumber('120')?.id, 'c119');
    vm.clearChannelFilters();
    vm.setChannelQuery('NBA PACKAGE');
    expect(vm.filteredChannels.single.id, 'c118');
    vm.setChannelQuery('');
    expect(vm.filteredChannels.length, 120);
    expect(vm.packageOptions.single.count, 1);
    expect(vm.countryOptions.length, 2);
    vm.setRecentChannels(['c119', 'removed-channel', 'c118']);
    vm.setFilter(GuideFilter.recentlyWatched);
    expect(vm.filteredChannels.map((channel) => channel.id), ['c119', 'c118']);
    vm.setChannelFilters(country: 'PR | Puerto Rico');
    expect(vm.filteredChannels.single.id, 'c119');
    await Future<void>.delayed(Duration.zero);
    vm.dispose();
  });

  test('channel search includes distant rows and exact jump ignores active filters', () async {
    final channels = List.generate(120, (i) => {
      ..._channel('c$i'), 'Name': i == 119 ? 'TNT East' : 'Station $i',
      'ChannelNumber': i == 119 ? '4001' : '${i + 1}',
      'UserData': {'IsFavorite': i == 0},
    });
    when(() => liveTv.getChannels(
      sortBy: any(named: 'sortBy'), sortOrder: any(named: 'sortOrder'),
      fields: any(named: 'fields'), enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
      userId: any(named: 'userId'),
    )).thenAnswer((_) async => {'Items': channels});
    final vm = LiveTvGuideViewModel(client);
    await vm.load();
    vm.setChannelQuery(' tNt ');
    await Future<void>.delayed(Duration.zero);
    expect(vm.filteredChannels.single.id, 'c119');
    expect(vm.hasProgramsFor('c119'), true);
    expect(vm.programsHighWater, 50);
    vm.setFilter(GuideFilter.favorites);
    expect(vm.filteredChannels, isEmpty);
    expect(vm.channelForNumber(' 4001 ')?.id, 'c119');
    expect(vm.channelForNumber('400'), isNull);
    expect(vm.channelForNumber(''), isNull);
    vm.setFilter(GuideFilter.all);
    vm.setChannelQuery('4001');
    expect(vm.filteredChannels.single.id, 'c119');
    vm.setChannelQuery('');
    expect(vm.filteredChannels, hasLength(120));
    expect(() => vm.channels.clear(), throwsUnsupportedError);
    await Future<void>.delayed(Duration.zero);
    vm.dispose();
  });
}
