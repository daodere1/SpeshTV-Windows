import 'dart:async';

/// Polls the shared server snapshot only while the calendar is visible.
class CalendarRefreshLoop {
  CalendarRefreshLoop({
    required this.onRefresh,
    required this.isBusy,
    this.interval = const Duration(seconds: 60),
  });
  final void Function() onRefresh;
  final bool Function() isBusy;
  final Duration interval;
  Timer? _timer;
  void setActive(bool active) {
    if (!active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(interval, (_) {
      if (!isBusy()) onRefresh();
    });
  }

  void dispose() => setActive(false);
}
