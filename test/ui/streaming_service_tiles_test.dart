import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/spesh_streaming_services.dart';

void main() {
  testWidgets('all nine services show bundled original artwork and names', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Wrap(children: [
      for (final service in speshStreamingServices)
        StreamingServiceTile(service.name, onPressed: () {}),
    ]))));
    await tester.pumpAndSettle();
    for (final service in speshStreamingServices) {
      expect(find.text(service.name), findsOneWidget);
    }
    expect(find.byType(Image), findsNWidgets(9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone chooser scrolls with large labels and preserves selection', (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(MaterialApp(builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async { selected = await pickSpeshStudio(context); },
        child: const Text('Open'),
      )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Discovery+'));
    await tester.tap(find.text('Discovery+'));
    await tester.pumpAndSettle();
    expect(selected, 'Discovery+');
    expect(tester.takeException(), isNull);
  });
}
