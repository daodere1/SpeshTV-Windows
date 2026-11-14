import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native desktop alternatives to a channel's pointer context menu.
/// Repeats/releases are consumed without opening additional menus.
KeyEventResult handleGuideContextKey(KeyEvent event, void Function() open) {
  final contextKey = event.logicalKey == LogicalKeyboardKey.contextMenu;
  final shiftedF10 = event.logicalKey == LogicalKeyboardKey.f10 &&
      HardwareKeyboard.instance.isShiftPressed;
  if (!contextKey && !shiftedF10) return KeyEventResult.ignored;
  if (event is KeyDownEvent) open();
  return KeyEventResult.handled;
}
