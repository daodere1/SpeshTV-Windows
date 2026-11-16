import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/repositories/anime_marker_repository.dart';
import 'package:moonfin/ui/widgets/spesh_anime_badges.dart';

class _Markers extends Mock implements AnimeMarkerRepository {}

void main() {
  testWidgets('poster combines episode classification with item audio', (tester) async {
    final repo = _Markers();
    when(() => repo.getForItem('episode')).thenAnswer((_) async => AnimeAudioKind.subbedAndDubbed);
    when(() => repo.getForSeries('series')).thenAnswer((_) async => null);
    when(() => repo.peek(seriesId: 'series', episodeId: 'episode')).thenReturn(
      const AnimeEpisodeMarker(kind: AnimeEpisodeKind.mixed, recap: true));
    GetIt.instance.registerSingleton<AnimeMarkerRepository>(repo);
    addTearDown(() => GetIt.instance.unregister<AnimeMarkerRepository>());
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(width: 110,
      child: SpeshAnimeItemAudioBadge(itemId: 'episode', seriesId: 'series')))));
    await tester.pumpAndSettle();
    expect(find.text('Mixed'), findsOneWidget);
    expect(find.text('Recap'), findsOneWidget);
    expect(find.text('Subbed + dubbed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final entry in {
    AnimeEpisodeKind.mangaCanon: 'Manga canon',
    AnimeEpisodeKind.animeCanon: 'Anime canon',
    AnimeEpisodeKind.mixed: 'Mixed',
    AnimeEpisodeKind.filler: 'Filler',
  }.entries) {
    testWidgets('${entry.value} fits a narrow poster with recap and audio', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 110,
        child: SpeshAnimeMarkerLabels(marker: AnimeEpisodeMarker(
          kind: entry.key, recap: true, audio: AnimeAudioKind.subbedAndDubbed))))));
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Recap'), findsOneWidget);
      expect(find.text('Subbed + dubbed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('JoJo-style canon and dual-audio verdicts render', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      SpeshAnimeMarkerLabels(marker: AnimeEpisodeMarker(
        kind: AnimeEpisodeKind.mangaCanon, recap: false,
        audio: AnimeAudioKind.subbedAndDubbed)))));
    expect(find.text('Manga canon'), findsOneWidget);
    expect(find.text('Subbed + dubbed'), findsOneWidget);
    expect(find.text('Filler'), findsNothing);
  });
  testWidgets('confirmed marker labels fit narrow layout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(
      width: 220, child: SpeshAnimeMarkerLabels(marker: AnimeEpisodeMarker(
        kind: AnimeEpisodeKind.filler, recap: true,
        audio: AnimeAudioKind.subbedAndDubbed)),
    ))));
    expect(find.text('Filler'), findsOneWidget);
    expect(find.text('Recap'), findsOneWidget);
    expect(find.text('Subbed + dubbed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown markers and missing repository draw no badges', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      SpeshAnimeMarkerLabels(marker: AnimeEpisodeMarker(kind: null, recap: false)),
      SpeshAnimeBadges(seriesId: 'series', itemId: 'episode'),
    ])));
    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
