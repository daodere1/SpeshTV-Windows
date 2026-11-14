/// Detects persistent short rebuffers, not isolated network hiccups. The
/// allowance survives automatic source reopens within one viewing session.
class WindowsLiveRebufferWatch {
  WindowsLiveRebufferWatch({Duration Function()? now})
    : _now = now ?? (Stopwatch()..start()).read;
  final Duration Function() _now;
  Object? _session;
  Duration _began = Duration.zero;
  Duration? _bufferingAt;
  Duration? _lastRecovery;
  Duration? _lastPause;
  int _attempts = 0;
  final _episodes = <({Duration end, Duration length})>[];

  void beginSession(Object? session) {
    if (session == null || session != _session) {
      _session = session;
      _attempts = 0;
      _lastRecovery = null;
    }
    suspend();
  }

  void suspend() {
    _began = _now();
    _bufferingAt = null;
    _lastPause = null;
    _episodes.clear();
  }

  bool get recentlyInterrupted =>
      _bufferingAt != null ||
      (_lastPause != null &&
          _now() - _lastPause! < const Duration(seconds: 20));
  String get diagnostics =>
      'rebufferEpisodes=${_episodes.length} '
      'rebufferMs=${_episodes.fold<int>(0, (sum, e) => sum + e.length.inMilliseconds)} '
      'stabilityRejoins=$_attempts';

  bool observe(bool buffering, {required bool allowed}) {
    final now = _now();
    if (!allowed) {
      suspend();
      return false;
    }
    if (now - _began < const Duration(seconds: 20)) return false;
    if (buffering) {
      _bufferingAt ??= now;
      return false;
    }
    final start = _bufferingAt;
    _bufferingAt = null;
    if (start == null || now - start < const Duration(seconds: 1)) return false;
    _lastPause = now;
    _episodes.removeWhere((e) => now - e.end > const Duration(minutes: 1));
    _episodes.add((end: now, length: now - start));
    final total = _episodes.fold<Duration>(
      Duration.zero,
      (sum, e) => sum + e.length,
    );
    if (_episodes.length < 3 ||
        total < const Duration(seconds: 6) ||
        _attempts >= 2 ||
        (_lastRecovery != null &&
            now - _lastRecovery! < const Duration(minutes: 2)))
      return false;
    _attempts++;
    _lastRecovery = now;
    _episodes.clear();
    return true;
  }
}

/// Applies a modest live runway and restores the previous values before VOD.
/// Work is serialized, and ownership is checked across each native await.
class WindowsLiveBufferPolicy {
  WindowsLiveBufferPolicy({required this.read, required this.write});
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  static const live = {
    'cache': 'yes',
    'cache-pause': 'yes',
    'cache-pause-wait': '3',
    'cache-pause-initial': 'yes',
  };
  final _saved = <String, String>{};
  Future<void> _pending = Future.value();
  Future<void> apply({required bool enabled, required bool Function() owns}) {
    final work = _pending.then((_) async {
      if (!owns()) return;
      for (final entry in live.entries) {
        if (!owns()) return;
        if (enabled) {
          if (!_saved.containsKey(entry.key)) {
            final old = await read(entry.key);
            if (!owns()) return;
            // Unknown native values must not be changed irreversibly.
            if (old == null) continue;
            _saved[entry.key] = old;
          }
          await write(entry.key, entry.value);
        } else if (_saved.containsKey(entry.key)) {
          await write(entry.key, _saved[entry.key]!);
          _saved.remove(entry.key);
        }
      }
    });
    _pending = work.catchError((Object _) {});
    return work;
  }
}

extension on Stopwatch {
  Duration read() => elapsed;
}
