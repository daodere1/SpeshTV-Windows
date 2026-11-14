import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/detail_trailer.dart';

void main() {
  test('accepts canonical and embedded YouTube video links', () {
    for (final url in [
      'https://www.youtube.com/watch?v=abcdefghijk',
      'https://youtu.be/abcdefghijk',
      'https://www.youtube.com/embed/abcdefghijk',
    ]) {
      expect(youtubeTrailerId(url), 'abcdefghijk');
    }
  });
  test('rejects lookalike hosts, non-http schemes and invalid IDs', () {
    for (final url in [
      'https://youtube.com.evil.example/watch?v=abcdefghijk',
      'file://youtube.com/watch?v=abcdefghijk',
      'https://youtu.be/short',
    ]) {
      expect(youtubeTrailerId(url), isNull);
    }
  });
}
