import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/playback/media3_player_backend.dart';
import 'package:moonfin/preference/user_preferences.dart';

class Preferences extends Mock implements UserPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('non-Android startup never subscribes to the native Media3 channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const channel = MethodChannel('moonfin/media3_video_events');
    var calls = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async { calls++; return null; });
    try {
      final backend = Media3PlayerBackend(Preferences());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      backend.dispose();
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
