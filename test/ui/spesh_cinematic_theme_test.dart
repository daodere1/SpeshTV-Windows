import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin_design/moonfin_design.dart';

void main() {
  test(
    'Spesh web exposes only Cinematic and migrates old theme selections',
    () {
      if (!ThemeRegistry.cinematicOnly) return;
      expect(ThemeRegistry.availableThemes.keys, ['spesh-cinematic']);
      ThemeRegistry.setActiveById('spesha-style');
      expect(ThemeRegistry.active.id, 'spesh-cinematic');
      expect(ThemeRegistry.resolveById('neon_pulse').id, 'spesh-cinematic');
    },
  );
  tearDown(() {
    ThemeRegistry.replaceCustomThemes([]);
    ThemeRegistry.setActiveById(ThemeRegistry.moonfinId);
  });

  test('Cinematic stays available after server theme refresh', () {
    ThemeRegistry.replaceCustomThemes([]);
    final theme = ThemeRegistry.resolveById('spesh-cinematic');
    expect(theme.id, 'spesh-cinematic');
    expect(theme.colors.background, Colors.black);
    expect(theme.borders.cardRadius.topLeft.x, 22);
  });

  test('an administrator can override the bundled Cinematic theme', () {
    final json = ThemeRegistry.resolveById('spesh-cinematic').toJson();
    json['displayName'] = 'Server Cinematic';
    ThemeRegistry.replaceCustomThemes([ThemeSpec.fromJson(json)]);
    expect(
      ThemeRegistry.resolveById('spesh-cinematic').displayName,
      ThemeRegistry.cinematicOnly ? 'Spesh Cinematic' : 'Server Cinematic',
    );
    ThemeRegistry.replaceCustomThemes([]);
    expect(
      ThemeRegistry.resolveById('spesh-cinematic').displayName,
      'Spesh Cinematic',
    );
  });

  testWidgets('gradient focus border paints on rounded and circular controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Container(
              width: 160,
              height: 90,
              decoration: BoxDecoration(
                border: SpeshCinematicBorder(),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: SpeshCinematicBorder(),
              ),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
