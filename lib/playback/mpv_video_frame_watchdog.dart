import 'dart:async';
import 'dart:convert';

/// Only fresh render passes count. OSD redraws and the audio/playback clock
/// can keep updating while the video renderer is stuck. Missing telemetry is
/// unknown, never evidence of a freeze. No pixels or source URLs are sampled.
String? freshVideoFrameSignal(String? raw) {
  try {
    final value = jsonDecode(raw ?? '');
    if (value is! Map || value['fresh'] is! List) return null;
    final passes = value['fresh'] as List;
    final signals = <Object>[];
    for (final pass in passes) {
      if (pass is! Map) continue;
      final samples = pass['samples'];
      if (samples is! List ||
          samples.isEmpty ||
          samples.any((v) => v is! num || !v.isFinite))
        continue;
      signals.add([pass['desc'], samples]);
    }
    return signals.isEmpty ? null : jsonEncode(signals);
  } catch (_) {
    return null;
  }
}

/// Serial polling, session/visibility invalidation and monotonic stall timing.
/// One notification per freeze, rearmed only by fresh video or a reset.
class MpvVideoFrameWatchdog {
  MpvVideoFrameWatchdog({
    required this.eligible,
    required this.readSignal,
    required this.onFrozenChanged,
    this.onCheck,
    this.frameSeen,
    this.onProgress,
    Duration Function()? now,
    this.timeout = const Duration(seconds: 15),
  }) : _now = now ?? (Stopwatch()..start()).elapsedGetter;

  final bool Function() eligible;
  final Future<String?> Function() readSignal;
  final void Function(bool frozen) onFrozenChanged;
  final void Function()? onCheck;
  final bool Function()? frameSeen;
  final void Function()? onProgress;
  final Duration Function() _now;
  final Duration timeout;
  Timer? _timer;
  bool _active = false;
  bool _busy = false;
  bool _frozen = false;
  int _epoch = 0;
  String? _last;
  Duration? _changedAt;
  int _samples = 0;
  int _missing = 0;
  int _errors = 0;
  String get diagnostics =>
      'active=$_active busy=$_busy frozen=$_frozen '
      'samples=$_samples missing=$_missing errors=$_errors '
      'frameAgeMs=${_changedAt == null ? -1 : (_now() - _changedAt!).inMilliseconds}';

  bool? get advancing => !_active || _last == null || _changedAt == null
      ? null
      : !_frozen && _now() - _changedAt! <= const Duration(seconds: 6);

  void _notifyCheck() {
    try {
      onCheck?.call();
    } catch (_) {
      /* Observation cannot stop recovery. */
    }
  }

  void start() {
    stop();
    _active = true;
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(check()),
    );
    _notifyCheck();
  }

  void reset() {
    _epoch++;
    _last = null;
    _changedAt = null;
    _setFrozen(false);
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    reset();
    _notifyCheck();
  }

  void _setFrozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    onFrozenChanged(value);
  }

  Future<void> check() async {
    if (!_active) return;
    if (!eligible()) {
      reset();
      _notifyCheck();
      return;
    }
    if (_busy) {
      _notifyCheck();
      return;
    }
    _busy = true;
    _notifyCheck();
    final epoch = _epoch;
    try {
      final signal = await readSignal();
      if (!_active || epoch != _epoch || !eligible()) return;
      _samples++;
      if (signal == null) {
        _missing++;
        reset();
        return;
      }
      final now = _now();
      if (signal != _last) {
        _last = signal;
        _changedAt = now;
        _setFrozen(false);
        if (frameSeen?.call() != false) onProgress?.call();
      } else if (_changedAt != null &&
          now - _changedAt! >=
              (frameSeen?.call() == false
                  ? const Duration(seconds: 30)
                  : timeout)) {
        _setFrozen(true);
      }
    } catch (_) {
      _errors++;
      if (_active && epoch == _epoch) reset();
    } finally {
      _busy = false;
      _notifyCheck();
    }
  }
}

extension on Stopwatch {
  Duration elapsedGetter() => elapsed;
}
