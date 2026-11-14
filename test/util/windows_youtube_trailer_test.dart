import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/windows_youtube_trailer.dart';

void main() {
  test('official player has loopback origin and standard controls', () {
    final html = windowsTrailerHtml('abcdefghijk', 'http://127.0.0.1:43210');
    expect(html, contains('https://www.youtube.com/iframe_api'));
    expect(html, contains("origin:'http://127.0.0.1:43210'"));
    expect(html, contains('controls:1'));
    expect(html, contains("widget_referrer:'https://dev.speshmedia.speshtv/'"));
    expect(html, contains('strict-origin-when-cross-origin'));
    expect(html, contains("notify('ended')"));
    expect(html, contains("notify('error:'+e.data)"));
  });

  test('rejects invalid IDs and non-loopback origins', () {
    expect(() => windowsTrailerHtml("bad'ID", 'http://127.0.0.1:43210'), throwsArgumentError);
    expect(() => windowsTrailerHtml('abcdefghijk', 'https://example.com'), throwsArgumentError);
  });
}
