import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/ui/widgets/spesh_episode_filters.dart';

void main() {
  test('filters preserve watched semantics', () {
    expect(matchesEpisodeFilter(SpeshEpisodeFilter.all,
      played: true, position: Duration.zero), isTrue);
    expect(matchesEpisodeFilter(SpeshEpisodeFilter.unwatched,
      played: false, position: const Duration(seconds: 20)), isTrue);
    expect(matchesEpisodeFilter(SpeshEpisodeFilter.inProgress,
      played: true, position: const Duration(seconds: 20)), isFalse);
    expect(matchesEpisodeFilter(SpeshEpisodeFilter.inProgress,
      played: false, position: Duration.zero), isFalse);
    expect(matchesEpisodeFilter(SpeshEpisodeFilter.inProgress,
      played: false, position: const Duration(seconds: 20)), isTrue);
  });
  testWidgets('filter and jump controls fit narrow screens', (tester) async {
    SpeshEpisodeFilter? selected;
    var jumped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 320,
      child: SpeshEpisodeFilters(selected: SpeshEpisodeFilter.all,
        onChanged: (value) => selected = value, onJump: () => jumped = true),
    ))));
    await tester.tap(find.text('In Progress'));
    expect(selected, SpeshEpisodeFilter.inProgress);
    await tester.tap(find.text('Jump to Next Up'));
    expect(jumped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
