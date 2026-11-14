import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/util/series_resume.dart';

AggregatedItem episode(String id, int ticks, {bool played = false}) =>
    AggregatedItem(id: id, serverId: 'server', rawData: {
      'Id': id,
      'Type': 'Episode',
      'UserData': {'PlaybackPositionTicks': ticks, 'Played': played},
    });

void main() {
  test('saved position wins over earlier unwatched episode', () {
    final saved = episode('2', 100000000);
    expect(savedSeriesEpisode([episode('1', 0), saved]), same(saved));
  });
  test('percentage or an unwatched flag alone is not saved progress', () {
    expect(savedSeriesEpisode([episode('1', 0)]), isNull);
  });
  test('completed episodes are not resumed', () {
    expect(savedSeriesEpisode([episode('1', 100000000, played: true)]), isNull);
  });
}
