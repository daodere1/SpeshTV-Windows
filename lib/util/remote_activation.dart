import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool isRemoteActivation(KeyEvent event) =>
    event.logicalKey == LogicalKeyboardKey.select ||
    event.logicalKey == LogicalKeyboardKey.enter;

KeyEventResult handleRemoteActivation(KeyEvent event, VoidCallback activate) {
  if (!isRemoteActivation(event)) return KeyEventResult.ignored;
  if (event is KeyDownEvent) {
    activate();
    return KeyEventResult.handled;
  }
  return event is KeyRepeatEvent ? KeyEventResult.handled : KeyEventResult.ignored;
}
