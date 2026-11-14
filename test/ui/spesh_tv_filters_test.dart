import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/channel_facets.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_tv_filter_selector.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_guide_control_focus.dart';

void main() {
  testWidgets('picker initially selects All or the saved option, never Cancel', (tester) async {
    for (final value in ['', 'NHL']) {
      String? selected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300,
        child: SpeshTvFilterSelector(label: 'Package', value: value,
          options: const [ChannelFilterOption('NHL', 12)], onSelected: (v) => selected = v)))));
      await tester.tap(find.byType(OutlinedButton)); await tester.pumpAndSettle();
      final focused = tester.widgetList<TextButton>(find.byType(TextButton))
        .where((button) => button.focusNode?.hasFocus ?? false).toList();
      expect(focused, hasLength(1));
      expect(focused.single.focusNode!.debugLabel, 'SelectedGuideFilter');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); await tester.pumpAndSettle();
      expect(selected, value);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('TV tag picker selects with remote and restores opener focus', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300,
      child: SpeshTvFilterSelector(label: 'Tag / group', value: '',
        options: const [ChannelFilterOption('NHL', 12)], onSelected: (v) => selected = v)))));
    final opener = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'NHL');
    expect(find.byType(AlertDialog), findsNothing);
    expect(opener.onPressed, isNotNull);
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV picker cancels without changing filter and mounts distant selection', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300,
      child: SpeshTvFilterSelector(label: 'Tag / group', value: 'Group 199',
        options: List.generate(200, (i) => ChannelFilterOption('Group $i', 1)),
        onSelected: (v) => selected = v)))));
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.text('Group 199 (1)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed TV control focus does not scroll its ancestors', (tester) async {
    final controller = ScrollController();
    final first = FocusNode(), second = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      controller: controller, child: SpeshGuideControlFocus(child: Column(children: [
        TextButton(focusNode: first, onPressed: () {}, child: const Text('Country')),
        const SizedBox(height: 900),
        TextButton(focusNode: second, onPressed: () {}, child: const Text('Tag')),
      ]))))));
    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(second.hasFocus, isTrue);
    expect(controller.offset, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
