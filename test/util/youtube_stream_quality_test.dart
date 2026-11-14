import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/youtube_stream_resolver.dart';

Map<String, dynamic> stream(int height, {bool audio = true}) => {
  'url': 'https://example.test/$height',
  'height': height,
  'mimeType': 'video/mp4; codecs="avc1"',
  'videoOnly': !audio,
};

void main() {
  test('360p cap selects muxed MP4 without mutating candidates', () {
    final candidates = [stream(720), stream(240), stream(360)];
    expect(YouTubeStreamResolver.pickStreamUrl(candidates, maxHeight: 360),
        'https://example.test/360');
    expect(candidates.first['height'], 720);
  });
  test('uses lower resolution when 360p is absent', () {
    expect(YouTubeStreamResolver.pickStreamUrl([stream(240), stream(720)], maxHeight: 360),
        'https://example.test/240');
  });
  test('never falls back to high, unknown, video-only or non-MP4 streams', () {
    expect(YouTubeStreamResolver.pickStreamUrl([
      stream(720), stream(0), stream(360, audio: false),
      {...stream(360), 'mimeType': 'video/webm'},
    ], maxHeight: 360), isNull);
  });
  test('recognizes provider quality labels and type fields', () {
    expect(YouTubeStreamResolver.pickStreamUrl([
      {'url':'https://example.test/360', 'qualityLabel':'360p',
        'type':'video/mp4; codecs="avc1, mp4a"'},
    ], maxHeight: 360), 'https://example.test/360');
  });
}
