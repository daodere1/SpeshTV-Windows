enum LiveStallAction { none, reconnect, exhausted }

class LiveStallWatchdog {
  Duration? _lastProgress;
  Duration? _stableSince;
  Duration? _position;
  bool _hasPlayed = false;
  int attempts = 0;
  bool exhausted = false;

  void reset(Duration now) {
    attempts = 0;
    exhausted = false;
    _position = null;
    _hasPlayed = false;
    _stableSince = null;
    _lastProgress = now;
  }

  void reconnected(Duration now) {
    _position = null;
    _hasPlayed = false;
    _stableSince = null;
    _lastProgress = now;
  }

  LiveStallAction sample(Duration now, Duration position, {required bool active}) {
    if (!active) {
      _lastProgress = now;
      _stableSince = null;
      _position = position;
      return LiveStallAction.none;
    }
    if (exhausted) return LiveStallAction.none;
    if (_position == null || (position - _position!).abs() >= const Duration(milliseconds: 250)) {
      if (position > Duration.zero) _hasPlayed = true;
      if (_lastProgress == null || now - _lastProgress! > const Duration(seconds: 4)) _stableSince = null;
      _position = position;
      _lastProgress = now;
      if (_hasPlayed) _stableSince ??= now;
      if (_stableSince != null && now - _stableSince! >= const Duration(seconds: 30)) attempts = 0;
      return LiveStallAction.none;
    }
    _lastProgress ??= now;
    final timeout = Duration(seconds: _hasPlayed ? 12 : 30);
    if (now - _lastProgress! < timeout) return LiveStallAction.none;
    _stableSince = null;
    if (attempts >= 2) {
      exhausted = true;
      return LiveStallAction.exhausted;
    }
    attempts++;
    reconnected(now);
    return LiveStallAction.reconnect;
  }
}
