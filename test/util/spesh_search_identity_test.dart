import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/search_source.dart';

AggregatedItem item(String id, {String source = 'vod', String name = 'A Movie',
  int? year = 2020, Map<String, String> ids = const {}, String type = 'Movie',
  String server = 'server'}) => AggregatedItem(id: id, serverId: server,
    rawData: {'Name': name, 'Type': type, 'ProductionYear': year,
      'ProviderIds': ids, 'SpeshSource': source});

void main() {
  test('VOD is a library token, not a substring', () {
    expect(isVodLibrary('VOD 4K Movies'), isTrue);
    expect(isVodLibrary('My VOD TV Shows'), isTrue);
    expect(isVodLibrary('VODKA documentaries'), isFalse);
  });
  test('local copy wins with matching provider ID despite language label', () {
    final results = preferLocalSearchResults([
      item('vod', name: 'A Movie (Spanish)', ids: {'Tmdb': '10'}),
      item('local', source: 'local', ids: {'tmdb': '10'}),
    ]);
    expect(results.map((i) => i.id), ['local']);
  });
  test('conflicting IDs and remakes remain separate', () {
    expect(preferLocalSearchResults([
      item('a', ids: {'Tmdb': '10'}), item('b', ids: {'Tmdb': '11'}),
      item('c', year: 2021),
    ]), hasLength(3));
  });
  test('ID-less item cannot bridge incompatible provider IDs', () {
    expect(preferLocalSearchResults([
      item('a', ids: {'Tmdb': '10'}), item('b'), item('c', ids: {'Tmdb': '11'}),
    ]), hasLength(2));
  });
  test('unknown years and unrelated episodes never collapse by title', () {
    expect(preferLocalSearchResults([item('a', year: null), item('b', year: null)]), hasLength(2));
    expect(preferLocalSearchResults([item('a', type: 'Episode'), item('b', type: 'Episode')]), hasLength(2));
  });
  test('different servers stay separate; duplicate identical ID collapses', () {
    expect(preferLocalSearchResults([item('a'), item('a', server: 'other')]), hasLength(2));
    expect(preferLocalSearchResults([item('a'), item('a')]), hasLength(1));
  });
}
