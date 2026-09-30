import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/navigation/spesh_web_entry.dart';

void main() {
  test('restores the requested guide once after startup', () {
    final entry = SpeshWebEntry('/live-tv/guide');
    entry.capture('/startup');
    expect(entry.take(), '/live-tv/guide');
    expect(entry.take(), isNull);
  });
  test('only explicitly supported internal entry points can be restored', () {
    for (final path in [null, '/home', '/admin', '//other.example',
      'https://other.example', '/live-tv/guide?token=secret']) {
      expect(SpeshWebEntry(path).take(), isNull);
    }
    final entry = SpeshWebEntry(null)..capture('/live-tv');
    expect(entry.take(), '/live-tv');
  });
}
