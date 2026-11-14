/// Bounded, credential-free state retained even when logging is enabled late.
abstract final class WindowsVideoWatchDiagnostics {
  static const feature = 'frame-watch-v2';
  static const compiledVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');
  static const compiledBuild = String.fromEnvironment('FLUTTER_BUILD_NUMBER');
  static String packageVersion = '';
  static String packageBuild = '';
  static String snapshot = 'not-created';
  static String _lastKey = '';
  static final _clock = Stopwatch()..start();
  static Duration? _lastLog;
  static void Function(String)? log;

  static String get identity =>
      'package=${packageVersion.isEmpty ? "unknown" : packageVersion}'
      '+${packageBuild.isEmpty ? "unknown" : packageBuild} '
      'compiled=${compiledVersion.isEmpty ? "unknown" : compiledVersion}'
      '+${compiledBuild.isEmpty ? "unknown" : compiledBuild} feature=$feature';

  static void update(String safeState, String stateKey) {
    snapshot = safeState;
    final now = _clock.elapsed;
    if (stateKey != _lastKey ||
        _lastLog == null ||
        now - _lastLog! >= const Duration(seconds: 30)) {
      _lastKey = stateKey;
      _lastLog = now;
      try {
        log?.call('Windows video watch: $safeState');
      } catch (_) {
        // Diagnostics must never affect playback or its recovery loop.
      }
    }
  }
}
