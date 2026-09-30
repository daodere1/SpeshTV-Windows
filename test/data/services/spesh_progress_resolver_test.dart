import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/home_row.dart';
import 'package:moonfin/data/services/spesh_progress_resolver.dart';

class Client extends Mock implements MediaServerClient {}

class Items extends Mock implements ItemsApi {}

class Views extends Mock implements UserViewsApi {}

AggregatedItem item(
  String id, {
  String? series,
  String name = 'Example',
  int? year = 2020,
  String? tmdb = '10',
  int position = 0,
  String server = 'server',
}) => AggregatedItem(
  id: id,
  serverId: server,
  rawData: {
    'Id': id,
    'Name': name,
    'Type': series == null ? 'Movie' : 'Episode',
    'SeriesId': series,
    'ProductionYear': year,
    'ProviderIds': tmdb == null ? <String, String>{} : {'Tmdb': tmdb},
    'UserData': {'PlaybackPositionTicks': position},
  },
);

void main() {
  late Client client;
  late Items api;
  late Views views;
  late SpeshProgressResolver resolver;
  late Map<String, Map<String, dynamic>> catalog;
  late Map<String, String> libraries;
  late List<Map<String, dynamic>> matches;
  setUp(() {
    client = Client();
    api = Items();
    views = Views();
    catalog = {};
    libraries = {};
    matches = [];
    when(() => client.userId).thenReturn('user');
    when(() => client.itemsApi).thenReturn(api);
    when(() => client.userViewsApi).thenReturn(views);
    when(() => views.getUserViews()).thenAnswer(
      (_) async => {
        'Items': [
          {'Id': 'local', 'Name': 'HD Movies', 'CollectionType': 'movies'},
          {'Id': 'vod', 'Name': 'VOD Movies', 'CollectionType': 'movies'},
        ],
      },
    );
    when(
      () => api.getItem(any(), fields: any(named: 'fields')),
    ).thenAnswer((call) async => catalog[call.positionalArguments[0]]!);
    when(() => api.getAncestors(any())).thenAnswer(
      (call) async => [
        {'Id': libraries[call.positionalArguments[0]]},
      ],
    );
    when(
      () => api.getItems(
        parentId: any(named: 'parentId'),
        recursive: true,
        includeItemTypes: any(named: 'includeItemTypes'),
        limit: 50,
        anyProviderIdEquals: any(named: 'anyProviderIdEquals'),
        searchTerm: any(named: 'searchTerm'),
        fields: any(named: 'fields'),
        collapseBoxSetItems: false,
        enableTotalRecordCount: false,
      ),
    ).thenAnswer((_) async => {'Items': matches});
    resolver = SpeshProgressResolver(client);
  });
  void add(AggregatedItem entry, String library) {
    catalog[entry.id] = entry.rawData;
    libraries[entry.id] = library;
  }

  test('local movie replaces VOD without copying VOD progress', () async {
    final vod = item('v', name: 'Example (Spanish)', position: 900);
    final local = item('l', position: 20);
    add(vod, 'vod');
    add(local, 'local');
    final results = await resolver.resolve([vod, local]);
    expect(results.map((i) => i.id), ['l']);
    expect(results.single.playbackPositionTicks, 20);
    expect(vod.playbackPositionTicks, 900);
    verifyNever(() => api.getItem(any(), fields: any(named: 'fields')));
  });
  test(
    'different episodes of a matching series collapse to local progress',
    () async {
      final vodSeries = item('vs');
      final localSeries = item('ls');
      catalog['vs'] = {...vodSeries.rawData, 'Type': 'Series'};
      catalog['ls'] = {...localSeries.rawData, 'Type': 'Series'};
      libraries.addAll({'vs': 'vod', 'ls': 'local'});
      final results = await resolver.resolve([
        item('v-ep', series: 'vs'),
        item('l-ep', series: 'ls', position: 42),
      ]);
      expect(results.map((i) => i.id), ['l-ep']);
      expect(results.single.playbackPositionTicks, 42);
    },
  );
  test(
    'confirmed local catalog copy hides VOD even without local progress',
    () async {
      final vod = item('v');
      final local = item('l');
      add(vod, 'vod');
      add(local, 'local');
      matches = [local.rawData];
      expect(await resolver.resolve([vod]), isEmpty);
      verifyNever(() => api.getAncestors('l'));
      final requests = verify(
        () => api.getItems(
          parentId: captureAny(named: 'parentId'),
          recursive: true,
          includeItemTypes: any(named: 'includeItemTypes'),
          limit: 50,
          anyProviderIdEquals: any(named: 'anyProviderIdEquals'),
          searchTerm: any(named: 'searchTerm'),
          fields: any(named: 'fields'),
          collapseBoxSetItems: false,
          enableTotalRecordCount: false,
        ),
      ).captured;
      expect(requests, ['local']);
    },
  );
  test(
    'VOD-only titles remain, and failures do not hide an unconfirmed copy',
    () async {
      final vod = item('v');
      add(vod, 'vod');
      expect((await resolver.resolve([vod])).single.id, 'v');
      when(() => api.getAncestors('v')).thenThrow(StateError('offline'));
      resolver = SpeshProgressResolver(client);
      expect((await resolver.resolve([vod])).single.id, 'v');
    },
  );
  test(
    'conflicting provider IDs and different remakes remain separate',
    () async {
      final a = item('a', tmdb: '10');
      final b = item('b', tmdb: '11');
      add(a, 'vod');
      add(b, 'local');
      matches = [b.rawData];
      expect(await resolver.resolve([a, b]), hasLength(2));
      expect(
        sameProgressEntity(
          item('c', tmdb: null, year: 1990),
          item('d', tmdb: null, year: 2020),
        ),
        false,
      );
      expect(sameProgressEntity(item('c', server: 'other'), item('d')), false);
    },
  );
  test('known year and cleaned language/date suffix can match without IDs', () {
    expect(
      sameProgressEntity(
        item(
          'v',
          tmdb: null,
          name: 'All Rise (2019-2023) (English)',
          year: 2019,
        ),
        item('l', tmdb: null, name: 'All Rise', year: 2019),
      ),
      true,
    );
    expect(
      sameProgressEntity(
        item('v', tmdb: null, year: null),
        item('l', tmdb: null, year: null),
      ),
      false,
    );
  });
  test('ID-less item cannot join two incompatible identities', () async {
    final rows = [
      item('a', tmdb: '10'),
      item('b', tmdb: null),
      item('c', tmdb: '11'),
    ];
    for (final row in rows) {
      add(row, 'local');
    }
    expect(await resolver.resolve(rows), hasLength(2));
  });
  test('local resume wins over local next-up even if loaded later', () async {
    catalog['s'] = {...item('s').rawData, 'Type': 'Series'};
    libraries['s'] = 'local';
    final next = item('next', series: 's');
    final resume = item('resume', series: 's');
    final tagged = AggregatedItem(
      id: resume.id,
      serverId: resume.serverId,
      rawData: {...resume.rawData, 'SpeshProgressFeed': 'resume'},
    );
    expect((await resolver.resolve([next, tagged])).single.id, 'resume');
  });
  test(
    'metadata descriptions are reused for multiple episodes and subsequent pages',
    () async {
      catalog['s'] = {...item('s').rawData, 'Type': 'Series'};
      libraries['s'] = 'local';
      await resolver.resolve([
        item('e1', series: 's'),
        item('e2', series: 's'),
      ]);
      await resolver.resolve([item('e3', series: 's')]);
      verify(() => api.getItem('s', fields: any(named: 'fields'))).called(1);
    },
  );

  HomeRow page(List<AggregatedItem> rows, int total) => HomeRow(
    id: 'test',
    title: 'test',
    rowType: HomeRowType.resume,
    items: rows,
    totalCount: total,
  );
  test('no-count full pages remain pageable until a short page', () async {
    final offsets = <int>[];
    final feed = SpeshProgressFeed(
      resolve: (rows) async => rows,
      resume: (offset) async {
        offsets.add(offset);
        return page(
          List.generate(
            offset == 0 ? 15 : 1,
            (i) => item('item-${offset + i}'),
          ),
          0,
        );
      },
      nextUp: (_) async => page([], 0),
      filterResume: (rows) => rows,
      filterNextUp: (rows) => rows,
    );
    expect((await feed.load(refresh: true))!.hasMore, true);
    final last = (await feed.load())!;
    expect(last.hasMore, false);
    expect(last.items, hasLength(16));
    expect(offsets, [0, 15]);
  });
  test(
    'duplicate-only pages do not terminate paging before a later unique title',
    () async {
      final offsets = <int>[];
      final feed = SpeshProgressFeed(
        resolve: (rows) async => rows.where((r) => r.id == 'unique').toList(),
        resume: (offset) async {
          offsets.add(offset);
          return offset < 30
              ? page(
                  List.generate(15, (i) => item('duplicate-${offset + i}')),
                  31,
                )
              : page([item('unique')], 31);
        },
        nextUp: (_) async => page([], 0),
        filterResume: (r) => r,
        filterNextUp: (r) => r,
      );
      final result = await feed.load(refresh: true);
      expect(result!.items.single.id, 'unique');
      expect(result.hasMore, false);
      expect(offsets, [0, 15, 30]);
    },
  );
  test('a failed source retains its own offset for retry', () async {
    var fail = true;
    final nextOffsets = <int>[];
    final feed = SpeshProgressFeed(
      resolve: (r) async => r,
      resume: (_) async => page([item('local')], 1),
      nextUp: (offset) async {
        nextOffsets.add(offset);
        if (fail) throw StateError('temporary');
        return page([item('next')], 1);
      },
      filterResume: (r) => r,
      filterNextUp: (r) => r,
    );
    final partial = (await feed.load(refresh: true))!;
    expect(partial.hasMore, true);
    expect(partial.complete, false);
    fail = false;
    final recovered = (await feed.load())!;
    expect(recovered.hasMore, false);
    expect(recovered.complete, true);
    expect(nextOffsets, [0, 0]);
  });
  test('invalidation rejects an older response', () async {
    final pending = Completer<HomeRow>();
    final feed = SpeshProgressFeed(
      resolve: (r) async => r,
      resume: (_) => pending.future,
      nextUp: (_) async => page([], 0),
      filterResume: (r) => r,
      filterNextUp: (r) => r,
    );
    final loading = feed.load(refresh: true);
    feed.invalidate();
    pending.complete(page([item('stale')], 1));
    expect(await loading, isNull);
  });
  test('fast source publishes deduplicated cards before slow source finishes', () async {
    final slow = Completer<HomeRow>();
    final first = Completer<List<AggregatedItem>>();
    final feed = SpeshProgressFeed(
      resolve: (rows) async => rows,
      resume: (_) async => page([item('fast')], 1),
      nextUp: (_) => slow.future,
      filterResume: (r) => r,
      filterNextUp: (r) => r,
    );
    final loading = feed.load(refresh: true, onPartial: (items, _) {
      if (!first.isCompleted) first.complete(items);
    });
    expect((await first.future).single.id, 'fast');
    slow.complete(page([item('slow')], 1));
    expect((await loading)!.items.map((i) => i.id), ['fast', 'slow']);
  });
  test('invalidation suppresses partial results during slow deduplication', () async {
    final resolving = Completer<List<AggregatedItem>>();
    final started = Completer<void>();
    final published = <List<AggregatedItem>>[];
    final feed = SpeshProgressFeed(
      resolve: (rows) {
        if (!started.isCompleted) started.complete();
        return resolving.future;
      },
      resume: (_) async => page([item('old')], 1),
      nextUp: (_) async => page([], 0),
      filterResume: (r) => r,
      filterNextUp: (r) => r,
    );
    final loading = feed.load(refresh: true, onPartial: (items, _) => published.add(items));
    await started.future;
    feed.invalidate();
    resolving.complete([item('old')]);
    expect(await loading, isNull);
    expect(published, isEmpty);
  });
  test(
    'successful empty response is complete and clears old progress',
    () async {
      var rows = [item('old')];
      final feed = SpeshProgressFeed(
        resolve: (r) async => r,
        resume: (_) async => page(rows, rows.length),
        nextUp: (_) async => page([], 0),
        filterResume: (r) => r,
        filterNextUp: (r) => r,
      );
      expect((await feed.load(refresh: true))!.items.single.id, 'old');
      rows = [];
      final empty = (await feed.load(refresh: true))!;
      expect(empty.items, isEmpty);
      expect(empty.complete, true);
      expect(empty.hasMore, false);
    },
  );
}
