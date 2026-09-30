import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/search_source.dart';

AggregatedItem channel(String id, String name, String number,
    {String? program}) => AggregatedItem(id: id, serverId: 's', rawData: {
      'Name': name, 'Type': 'TvChannel', 'ChannelNumber': number,
      if (program != null) 'CurrentProgram': {'Name': program},
    });

void main() {
  test('language and date suffixes collapse to the local result', () {
    final local = AggregatedItem(id: 'local', serverId: 's', rawData: {
      'Name': 'All Rise', 'Type': 'Series', 'ProductionYear': 2019,
      'SpeshSource': 'local',
    });
    final vod = AggregatedItem(id: 'vod', serverId: 's', rawData: {
      'Name': 'All Rise (2019-2023) (English)', 'Type': 'Series',
      'ProductionYear': 2019, 'SpeshSource': 'vod',
    });
    expect(preferLocalSearchResults([vod, local]).single.id, 'local');
    expect(searchIdentityTitle('Top Gun (Spanish) (1986)'), 'top gun');
  });
  test('conflicting provider IDs and different release years stay separate', () {
    AggregatedItem movie(String id, int year, String tmdb) =>
      AggregatedItem(id: id, serverId: 's', rawData: {
        'Name': 'Movie (English)', 'Type': 'Movie', 'ProductionYear': year,
        'ProviderIds': {'Tmdb': tmdb},
      });
    expect(preferLocalSearchResults([movie('a', 2000, '1'),
      movie('b', 2000, '2')]), hasLength(2));
    expect(sameSearchTitle(movie('a', 2000, ''), movie('b', 2020, '')), isFalse);
  });
  test('exact channel number wins over text matches before limiting', () {
    final items = [channel('text', 'Channel 4001 extra', '2'),
      channel('number', 'Sports', '4001')];
    expect(matchSearchChannels(items, ' 4001 ', limit: 1).single.id, 'number');
  });
  test('channel names rank ahead of current programme matches', () {
    final items = [channel('event', 'Sports', '1', program: 'UFC tonight'),
      channel('name', 'UFC', '4000')];
    expect(matchSearchChannels(items, 'ufc').map((i) => i.id), ['name', 'event']);
  });
  test('ties use numeric channel order and empty searches return nothing', () {
    final items = [channel('ten', 'Sports', '10'), channel('two', 'Sports', '2')];
    expect(matchSearchChannels(items, 'sports').map((i) => i.id), ['two', 'ten']);
    expect(matchSearchChannels(items, ''), isEmpty);
    expect(matchSearchChannels(items, 'studio:Sports'), isEmpty);
  });
}
