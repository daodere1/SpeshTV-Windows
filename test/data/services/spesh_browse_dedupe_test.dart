import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/spesh_browse_dedupe.dart';

AggregatedItem item(String id, String name, {String? tmdb, int year = 2020,
    String type = 'Movie', String server = 'server'}) => AggregatedItem(
  id: id, serverId: server, rawData: {
    'Name': name, 'Type': type, 'ProductionYear': year,
    if (tmdb != null) 'ProviderIds': {'Tmdb': tmdb},
  },
);

void main() {
  Future<String> source(AggregatedItem i) async => i.id.startsWith('local')
      ? 'local' : i.id.startsWith('vod') ? 'vod' : 'unknown';
  Future<List<String>> ids(List<AggregatedItem> items) async =>
      (await preferLocalBrowseItems(items, source)).map((i) => i.id).toList();

  test('local replaces matching VOD even on a later page', () async {
    final vod = item('vod', 'Title (English)', tmdb: '10');
    final first = await preferLocalBrowseItems([vod, item('other', 'Other')], source);
    final result = await preferLocalBrowseItems([
      ...first, item('local', 'Title', tmdb: '10'),
    ], source);
    expect(result.map((i) => i.id), ['local', 'other']);
  });
  test('VOD-only and unconfirmed sources remain', () async {
    expect(await ids([item('vod', 'Title'), item('other', 'Title')]), ['vod', 'other']);
  });
  test('language variants and conflicting IDs stay separate', () async {
    expect(await ids([
      item('vod-es', 'Title (Spanish)', tmdb: '10'),
      item('local-en', 'Title (English)', tmdb: '10'),
      item('vod-release', 'Title (English)', tmdb: '11'),
    ]), ['vod-es', 'local-en', 'vod-release']);
  });
  test('different years, types and servers stay separate', () async {
    expect((await ids([
      item('vod', 'Title'), item('local-year', 'Title', year: 2021),
      item('local-type', 'Title', type: 'Series'),
      item('local-server', 'Title', server: 'other'),
    ])).length, 4);
  });
  test('same-source editions are not collapsed', () async {
    expect(await ids([item('local-a', 'Title'), item('other', 'Other'), item('local-b', 'Title')]),
      ['local-a', 'other', 'local-b']);
  });
  test('ID-less match cannot bridge conflicting provider IDs', () async {
    expect(await ids([
      item('vod-a', 'Title', tmdb: '10'), item('local', 'Title'),
      item('vod-b', 'Title', tmdb: '11'),
    ]), ['local', 'vod-b']);
  });
  test('unique cards require no source requests and failures preserve candidates', () async {
    var calls = 0;
    Future<String> failing(AggregatedItem i) async { calls++; throw StateError('offline'); }
    await preferLocalBrowseItems([item('one', 'One'), item('two', 'Two')], failing);
    expect(calls, 0);
    final result = await preferLocalBrowseItems([item('vod', 'Title'), item('local', 'Title')], failing);
    expect(result.length, 2);
  });
}
