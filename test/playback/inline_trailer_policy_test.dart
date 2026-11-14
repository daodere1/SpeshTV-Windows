import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/inline_preview_engine.dart';

bool embedded({bool android = false, bool web = false, bool ios = false,
    bool mac = false, bool available = true}) => usesEmbeddedYouTubeForInlinePreview(
  available: available, isAndroid: android, isWeb: web, isIOS: ios, isMacOS: mac,
);

void main() {
  test('Android Spotlight uses native previews, not the failing embed', () {
    expect(embedded(android: true), isFalse);
    expect(usesMedia3ForInlinePreview(), isFalse);
  });
  test('web and Apple retain their existing embedded players', () {
    expect(embedded(web: true), isTrue);
    expect(embedded(ios: true), isTrue);
    expect(embedded(mac: true), isTrue);
  });
  test('unsupported or unavailable embed stays disabled', () {
    expect(embedded(), isFalse);
    expect(embedded(web: true, available: false), isFalse);
  });
}
