import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:moonfin/ui/widgets/stable_agenda_list.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/data/services/spesh_release_notes.dart';

class _Missing extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('missing');
}

void main() {
  test('calendar source/release/error copy exposes friendly labels only', () {
    expect(['Sonarr', 'Radarr', 'Jellyfin'].map(calendarSourceLabel), [
      'TV',
      'Movies',
      'Library',
    ]);
    expect(
      [
        'digitalRelease',
        'physicalRelease',
        'inCinemas',
      ].map(calendarReleaseLabel),
      ['Digital release', 'Physical release', 'In cinemas'],
    );
    expect(
      calendarFailureLabel(StateError('Sonarr Radarr credentials')),
      isNot(contains('Sonarr')),
    );
    expect(
      calendarFailureLabel(StateError('Sonarr Radarr credentials')),
      isNot(contains('Radarr')),
    );
  });
  test('calendar controls have readable unfocused colors and blue focus', () {
    final style = calendarControlStyle();
    expect(style.backgroundColor!.resolve({}), const Color(0xFF151515));
    expect(style.foregroundColor!.resolve({}), const Color(0xFFF3F5F6));
    expect(
      style.backgroundColor!.resolve({WidgetState.selected}),
      const Color(0xFF25272C),
    );
    expect(
      style.side!.resolve({WidgetState.focused})!.color,
      const Color(0xFF8ABCF4),
    );
  });
  test(
    'bundled notes match this build and absent notes have safe fallback',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final notes = await SpeshReleaseNotes.load(version: '3.0.0+30000210');
      expect(notes, contains('SpeshTV Windows 3.0.0'));
      expect(notes, contains('fill the entire Spotlight frame'));
      final missing = await SpeshReleaseNotes.load(
        version: '0.0.0+0',
        bundle: _Missing(),
      );
      expect(missing, contains('SpeshTV'));
      expect(missing, contains('not available'));
      expect(missing.trim(), isNotEmpty);
    },
  );
  testWidgets('refresh insertion retains focused row and viewport anchor', (
    tester,
  ) async {
    var rows = [for (var n = 0; n < 40; n++) '$n'];
    late StateSetter update;
    final nodes = {for (var n = 0; n < 40; n++) '$n': FocusNode()};
    addTearDown(() {
      for (final node in nodes.values) {
        node.dispose();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return StableAgendaList<String>(
                items: rows,
                identity: (s) => s,
                itemBuilder: (context, s, prior) => SizedBox(
                  height: 100,
                  child: TextButton(
                    focusNode: nodes[s],
                    onPressed: () {},
                    child: Text('Row $s'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final visible = find.text('Row 11');
    await tester.ensureVisible(visible);
    await tester.pumpAndSettle();
    nodes['11']!.requestFocus();
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(visible).dy;
    update(() => rows = ['new', ...rows]);
    await tester.pumpAndSettle();
    expect(nodes['11']!.hasFocus, true);
    expect(tester.getTopLeft(visible).dy, closeTo(top, 1));
    expect(tester.takeException(), isNull);
  });
}
