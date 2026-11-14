import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/channel_facets.dart';

void main() {
  test('college package names and tags are recognized without pro false positives', () {
    expect(ChannelFacets.fromChannel('CFB 01', {}).packages, {'College football'});
    expect(ChannelFacets.fromChannel('NcaaF 01', {}).packages, {'College football'});
    expect(ChannelFacets.fromChannel('NcaaB 01', {}).packages, {'College basketball'});
    expect(ChannelFacets.fromChannel('Event', {'Tags': ['US | COLLEGE BASKETBALL PACKAGE']}).packages,
      {'College basketball'});
    expect(ChannelFacets.fromChannel('NCAA Baseball 02', {}).packages,
      {'College baseball', 'College sports / NCAA'});
    expect(ChannelFacets.fromChannel('Event', {'Genres': ['NCAA PACKAGE']}).packages,
      {'College sports / NCAA'});
    expect(ChannelFacets.fromChannel('NFL 01', {}).packages, isEmpty);
  });
  test('country prefixes and group tags resolve PR DR CH without programme data', () {
    expect(ChannelFacets.fromChannel('PR | WAPA', {}).countries, {'PR | Puerto Rico'});
    expect(ChannelFacets.fromChannel('Telemicro', {'Tags': ['DR | Dominican Republic']}).countries, {'DR | Dominican Republic'});
    expect(ChannelFacets.fromChannel('CH | CCTV 1', {}).countries, {'CH | China'});
    expect(ChannelFacets.fromChannel('CN: CCTV', {}).countries, {'CH | China'});
    expect(ChannelFacets.fromChannel('Dr. Phil', {}).countries, isEmpty);
    expect(ChannelFacets.fromChannel('PRIME NEWS', {}).countries, isEmpty);
  });

  test('sports packages come from channel tags, including PPV event group', () {
    final channel = ChannelFacets.fromChannel('NBA 04 : Game tonight', {'Tags': ['US| NBA PACKAGE', 'Sports']});
    expect(channel.packages, {'NBA'});
    expect(channel.countries, {'US | United States'});
    expect(ChannelFacets.fromChannel('NHL event', {'Tags': ['US| NHL PACKAGE']}).packages, {'NHL'});
    expect(ChannelFacets.fromChannel('UFC 02', {'Tags': ['UFC PACKAGE']}).packages, {'UFC'});
    expect(ChannelFacets.fromChannel('PPV event', {'Tags': ['1118']}).packages, {'PPV / Live events'});
    expect(ChannelFacets.fromChannel('ESPN PLUS 01', {'Tags': ['1118']}).packages, {'PPV / Live events', 'ESPN+'});
    expect(ChannelFacets.fromChannel('NBA TV', {}).packages, isEmpty);
  });

  test('tags split semicolon genres, ignore malformed values, count each channel once', () {
    final facets = ChannelFacets.fromChannel('Station', {'Tags': ['Kids;Family', 'Kids', null], 'Genres': ['Comedy']});
    expect(facets.tags, {'Kids', 'Family', 'Comedy'});
    expect(ChannelFacets.fromChannel('Station', {'Tags': 42, 'Genres': null}).tags, isEmpty);
    final options = channelFilterOptions([{'Kids', 'kids'}, {'Kids', 'Sports'}]);
    expect(options.map((o) => o.value), ['Kids', 'Sports']);
    expect(options.map((o) => o.count), [2, 1]);
  });
}
