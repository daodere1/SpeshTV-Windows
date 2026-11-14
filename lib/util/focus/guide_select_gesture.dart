import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dpad_keys.dart';

/// Select activates on release; a held select opens actions without also tuning.
class GuideSelectGesture {
  GuideSelectGesture({required this.onSelect, required this.onHeld});
  final VoidCallback onSelect;
  final VoidCallback onHeld;
  Timer? _timer;
  Timer? _releaseGuard;
  bool _pressed = false, _held = false, _guarding = false;

  void _unguard() {
    if (!_guarding) return;
    FocusManager.instance.removeEarlyKeyEventHandler(_consumeHeldRelease);
    _guarding = false;
    _releaseGuard?.cancel();
  }

  KeyEventResult _consumeHeldRelease(KeyEvent event) {
    if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      _pressed = false;
      _unguard();
    }
    return KeyEventResult.handled;
  }

  KeyEventResult handle(KeyEvent event) {
    if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;
    if (event is KeyDownEvent && !_pressed) {
      _pressed = true;
      _held = false;
      _timer = Timer(const Duration(milliseconds: 700), () {
        _held = true;
        _guarding = true;
        FocusManager.instance.addEarlyKeyEventHandler(_consumeHeldRelease);
        _releaseGuard = Timer(const Duration(seconds: 10), _unguard);
        onHeld();
      });
    } else if (event is KeyUpEvent) {
      _timer?.cancel();
      final activate = _pressed && !_held;
      _pressed = false;
      if (activate) onSelect();
    }
    return KeyEventResult.handled;
  }

  void cancel() {
    _timer?.cancel();
    _pressed = false;
  }

  void dispose() {
    cancel();
    // Once the dialog owns focus, swallow the originating release there too.
    if (!_held) _unguard();
  }
}

int restoredGuideRow(List<String> ids, String? previousId, int previousRow) {
  if (ids.isEmpty) return -1;
  final found = previousId == null ? -1 : ids.indexOf(previousId);
  return found >= 0 ? found : previousRow.clamp(0, ids.length - 1);
}
