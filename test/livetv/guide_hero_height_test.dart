import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/livetv/epg/widgets/epg_hero_preview.dart';

void main() {
  testWidgets('noncompact logo preview stays finite inside the guide column', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(
      children: [EpgHeroPreview(title: 'Channel', timeLabel: null,
        genreLabel: null, synopsis: null, isLive: false, apple: false,
        channelLogoUrl: ''), Expanded(child: SizedBox())]))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(EpgHeroPreview));
    expect(rect.height, EpgHeroPreview.compactHeight);
    expect(rect.top.isFinite && rect.bottom.isFinite, isTrue);
  });
  testWidgets('compact standalone hero keeps a fixed height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        // The hero sizes itself only when its parent leaves the height loose,
        // which is what the guide's Column gives it.
        home: Align(
          alignment: Alignment.topCenter,
          child: EpgHeroPreview(
            title: 'Program',
            timeLabel: '7:00 - 8:00',
            genreLabel: 'Drama',
            synopsis:
                'A synopsis that continues onto a second line for context.',
            isLive: false,
            apple: false,
            compact: true,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(EpgHeroPreview)).height,
      EpgHeroPreview.compactHeight,
    );
  });
}
