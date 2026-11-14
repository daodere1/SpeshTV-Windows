import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_guide_controls.dart';

void main() {
  testWidgets('Windows guide search keeps native caret navigation', (tester) async {
    final search = TextEditingController();
    final number = TextEditingController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SpeshGuideControls(
      searchController: search, numberController: number,
      onSearch: (_) {}, onJump: () {}, onHome: () {}, tvNavigation: false,
    ))));
    final field = find.widgetWithText(TextField, 'Search channels');
    await tester.enterText(field, 'USA Network');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.descendant(
      of: field, matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(search.selection.baseOffset, 'USA Network'.length - 1);
    expect(number.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    search.dispose();
    number.dispose();
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('Windows channel entry requests numeric input and submits once', (tester) async {
    final search = TextEditingController();
    final number = TextEditingController();
    var jumps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SpeshGuideControls(
      searchController: search, numberController: number,
      onSearch: (_) {}, onJump: () => jumps++, onHome: () {}, tvNavigation: false,
    ))));
    final field = find.widgetWithText(TextField, 'Channel #');
    expect(tester.widget<TextField>(field).keyboardType?.index,
      TextInputType.number.index);
    await tester.enterText(field, '10x0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(number.text, '100');
    expect(jumps, 1);
    await tester.pumpWidget(const SizedBox());
    search.dispose();
    number.dispose();
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
}
