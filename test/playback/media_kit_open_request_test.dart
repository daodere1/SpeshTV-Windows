import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/media_kit_open_request.dart';

void main() {
  test('live playback never applies a saved movie position', () {
    final request = mediaKitOpenRequest(
      'https://example.com/live.ts',
      startPosition: const Duration(minutes: 20),
      nativeResume: true,
      autoPlay: true,
      isLive: true,
    );
    expect(request.media.start, isNull);
    expect(request.play, isTrue);
  });
  test('native resume starts playing at the requested position', () {
    final request = mediaKitOpenRequest(
      'https://example.com/movie',
      startPosition: const Duration(minutes: 20),
      nativeResume: true,
      autoPlay: true,
      headers: {'User-Agent': 'test-client'},
    );
    expect(request.media.start, const Duration(minutes: 20));
    expect(request.play, isTrue);
    expect(request.media.httpHeaders, {'User-Agent': 'test-client'});
  });

  test('a new native title explicitly clears the old resume offset', () {
    final request = mediaKitOpenRequest(
      'https://example.com/movie',
      startPosition: Duration.zero,
      nativeResume: true,
      autoPlay: true,
    );
    expect(request.media.start, Duration.zero);
    expect(request.play, isTrue);
  });

  test('paused loading and other platforms retain their existing behavior', () {
    final paused = mediaKitOpenRequest(
      'https://example.com/movie',
      startPosition: const Duration(minutes: 20),
      nativeResume: true,
      autoPlay: false,
    );
    expect(paused.play, isFalse);
    final legacy = mediaKitOpenRequest(
      'https://example.com/movie',
      startPosition: const Duration(minutes: 20),
      nativeResume: false,
      autoPlay: true,
    );
    expect(legacy.media.start, isNull);
    expect(legacy.play, isFalse);
  });
}
