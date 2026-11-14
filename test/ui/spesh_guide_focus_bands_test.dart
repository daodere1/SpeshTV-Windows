import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_guide_control_focus.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_guide_controls.dart';

void main() {
  testWidgets('background guide focus requests do not steal a modal input', (tester) async {
    final scope = FocusScopeNode();
    final input = FocusNode();
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      page = context;
      return Scaffold(body: FocusScope(node: scope, child: TextButton(
        onPressed: () {}, child: const Text('Guide controls'))));
    })));
    showDialog<void>(context: page, builder: (_) => AlertDialog(
      content: TextField(autofocus: true, focusNode: input)));
    await tester.pumpAndSettle();
    focusSpeshGuideScope(scope);
    await tester.pump();
    expect(input.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    input.dispose(); scope.dispose();
  });
  testWidgets('channel number input requests numeric keyboard and rejects letters', (tester) async {
    final search = TextEditingController(), number = TextEditingController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SpeshGuideControls(
      searchController: search, numberController: number, onSearch: (_) {},
      onJump: () {}, onHome: () {}))));
    final field = find.widgetWithText(TextField, 'Channel #');
    expect(tester.widget<TextField>(field).keyboardType?.index, TextInputType.number.index);
    await tester.enterText(field, 'a12b.3');
    expect(number.text, '12.3');
    await tester.pumpWidget(const SizedBox());
    search.dispose(); number.dispose();
  });
  testWidgets('type row falls through an informational preview to Search', (tester) async {
    final type = FocusScopeNode();
    final preview = FocusScopeNode();
    final search = FocusScopeNode();
    final typeNode = FocusNode();
    final searchNode = FocusNode();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      SpeshGuideFocusBand(scope: type, onEntered: () {},
        onDown: () => focusSpeshGuideScope(preview, fallback: search),
        child: TextButton(focusNode: typeNode, onPressed: () {}, child: const Text('All'))),
      FocusScope(node: preview, child: const Text('Programme information')),
      SpeshGuideFocusBand(scope: search, onEntered: () {},
        onUp: () => focusSpeshGuideScope(preview, fallback: type),
        child: TextButton(focusNode: searchNode, onPressed: () {}, child: const Text('Search'))),
    ]))));
    typeNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(searchNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(typeNode.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    typeNode.dispose(); searchNode.dispose();
    type.dispose(); preview.dispose(); search.dispose();
  });
  testWidgets('guide type row stays reachable between toolbar and preview', (tester) async {
    final scopes = List.generate(4, (_) => FocusScopeNode());
    final nodes = List.generate(4, (_) => FocusNode());
    const labels = ['Toolbar', 'All / Movies / Series', 'Preview', 'Search'];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(
      children: List.generate(4, (i) => SpeshGuideFocusBand(
        scope: scopes[i], onEntered: () {},
        onUp: i == 0 ? null : () => focusSpeshGuideScope(scopes[i - 1]),
        onDown: i == 3 ? null : () => focusSpeshGuideScope(scopes[i + 1]),
        child: TextButton(focusNode: nodes[i], onPressed: () {}, child: Text(labels[i])),
      )),
    ))));
    nodes.first.requestFocus();
    await tester.pump();
    for (var i = 1; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodes[i].hasFocus, isTrue, reason: labels[i]);
    }
    for (var i = 2; i >= 0; i--) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(nodes[i].hasFocus, isTrue, reason: labels[i]);
    }
    await tester.pumpWidget(const SizedBox());
    for (final node in nodes) { node.dispose(); }
    for (final scope in scopes) { scope.dispose(); }
  });
  testWidgets('TV search arrows change controls only with keyboard closed', (tester) async {
    final search = TextEditingController(text: 'news');
    final number = TextEditingController();
    Future<void> show(double inset) => tester.pumpWidget(MaterialApp(home:
      MediaQuery(data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
        child: Scaffold(body: SpeshGuideControls(tvNavigation: true,
          searchController: search, numberController: number, onSearch: (_) {},
          onJump: () {}, onHome: () {})))));
    await show(0);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    fields[0].focusNode!.requestFocus(); await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); await tester.pump();
    expect(fields[1].focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); await tester.pump();
    expect(fields[0].focusNode!.hasFocus, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 100);
    addTearDown(tester.view.resetViewInsets);
    await show(100); await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); await tester.pump();
    expect(fields[0].focusNode!.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox()); search.dispose(); number.dispose();
  });
  testWidgets('every toolbar button enters controls and Up restores prior focus', (tester) async {
    final top = FocusScopeNode();
    final controls = FocusScopeNode();
    final facets = FocusScopeNode();
    final nodes = List.generate(5, (_) => FocusNode());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      SpeshGuideFocusBand(scope: top, onEntered: () {},
        onDown: () => focusSpeshGuideScope(controls),
        child: Row(children: List.generate(3, (i) => TextButton(
          focusNode: nodes[i], onPressed: () {}, child: Text('Top $i'))))),
      SpeshGuideFocusBand(scope: controls, onEntered: () {},
        onUp: () => focusSpeshGuideScope(top), onDown: () => focusSpeshGuideScope(facets),
        child: TextField(focusNode: nodes[3], decoration: const InputDecoration(labelText: 'Search'))),
      SpeshGuideFocusBand(scope: facets, onEntered: () {},
        onUp: () => focusSpeshGuideScope(controls),
        child: TextButton(focusNode: nodes[4], onPressed: () {}, child: const Text('Country'))),
    ]))));
    for (var i = 0; i < 3; i++) {
      nodes[i].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodes[3].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodes[4].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(nodes[3].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(nodes[i].hasFocus, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
    for (final node in nodes) { node.dispose(); }
    top.dispose(); controls.dispose(); facets.dispose();
  });

  test('Back dismisses keyboard only when visible; otherwise leaves guide', () {
    var dismissed = 0;
    var returned = 0;
    void back(bool visible) => handleSpeshGuideBack(keyboardVisible: visible,
      dismissKeyboard: () => dismissed++, returnHome: () => returned++);
    back(true);
    expect(dismissed, 1); expect(returned, 0);
    back(false);
    expect(dismissed, 1); expect(returned, 1);
  });
}
