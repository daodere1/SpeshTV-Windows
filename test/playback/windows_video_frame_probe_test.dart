import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/windows_video_frame_probe.dart';

void main() {
  test('visible unfocused Windows playback remains monitored; hidden playback does not', () {
    expect(windowsVideoWatchVisible(null), true);
    expect(windowsVideoWatchVisible(AppLifecycleState.resumed), true);
    expect(windowsVideoWatchVisible(AppLifecycleState.inactive), true);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(windowsVideoWatchVisible(state), false);
    }
  });
  Map<String, Object?> sample({int count = 12}) => {
    'schema': 2,
    'visible': true,
    'minimized': false,
    'fresh': count,
    'rendered': 20,
    'redraw': 8,
    'repeat': 0,
    'infoErrors': 0,
  };
  test('focus changes do not keep extending the stall deadline', () {
    expect(
      windowsVideoWatchNeedsReset(
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
      ),
      false,
    );
    expect(
      windowsVideoWatchNeedsReset(
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ),
      false,
    );
    expect(
      windowsVideoWatchNeedsReset(
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ),
      true,
    );
    expect(
      windowsVideoWatchNeedsReset(
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ),
      true,
    );
  });
  test('zero frames is valid startup telemetry, not silently unavailable', () {
    final probe = WindowsVideoFrameProbe.fromMap(sample(count: 0));
    expect(probe.signal, 'texture:0');
    expect(probe.status, 'awaiting_first_frame');
  });
  test(
    'actual frame progress has a numeric signal and only numeric diagnostics',
    () {
      final probe = WindowsVideoFrameProbe.fromMap(
        sample()..['redraw'] = 'private-value',
      );
      expect(probe.signal, 'texture:12');
      expect(probe.stats, contains('rendered=20'));
      expect(probe.stats, isNot(contains('private-value')));
    },
  );
  test('minimized and hidden native hosts never report a freeze signal', () {
    for (final hidden in [
      sample()..['visible'] = false,
      sample()..['minimized'] = true,
    ]) {
      final probe = WindowsVideoFrameProbe.fromMap(hidden);
      expect(probe.status, 'native_hidden');
      expect(probe.signal, isNull);
    }
  });
  test('mixed or missing renderer ABI is explicitly distinguishable', () {
    expect(
      WindowsVideoFrameProbe.fromMap({'schema': 1}).status,
      'native_schema_mismatch',
    );
    expect(WindowsVideoFrameProbe.fromMap(null).schema, isNull);
    expect(
      WindowsVideoFrameProbe.fromMap(sample()..remove('fresh')).status,
      'native_output_unavailable',
    );
    expect(
      WindowsVideoFrameProbe.fromMap(sample()..remove('visible')).status,
      'native_visibility_unknown',
    );
  });
}
