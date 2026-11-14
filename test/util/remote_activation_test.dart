import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/remote_activation.dart';

void main() {
  test('one Select press activates once and consumes held repeats', () {
    var count = 0;
    final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: LogicalKeyboardKey.select, timeStamp: Duration.zero);
    final repeat = KeyRepeatEvent(physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: LogicalKeyboardKey.select, timeStamp: const Duration(milliseconds: 100));
    expect(handleRemoteActivation(down, () => count++), KeyEventResult.handled);
    for (var i = 0; i < 5; i++) {
      expect(handleRemoteActivation(repeat, () => count++), KeyEventResult.handled);
    }
    expect(count, 1);
  });
}
