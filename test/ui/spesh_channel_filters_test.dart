import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/channel_facets.dart';
import 'package:moonfin/data/viewmodels/live_tv_guide_view_model.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_channel_filters.dart';

class MockClient extends Mock implements MediaServerClient {}

void main() {
  for (final width in [320.0, 820.0, 1280.0]) {
    testWidgets('filter count and clear fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = LiveTvGuideViewModel(MockClient());
      model.countryOptions = [const ChannelFilterOption('PR | Puerto Rico', 1)];
      model.setChannelFilters(country: 'PR | Puerto Rico');
      model.setFilter(GuideFilter.favorites);
      var clearedHistory = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListenableBuilder(
        listenable: model, builder: (context, _) => SpeshChannelFilters(model: model, onChanged: () {},
          onClearRecent: () => clearedHistory++),
      ))));
      expect(tester.takeException(), isNull);
      model.setFilter(GuideFilter.recentlyWatched);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Clear recently watched channels'));
      expect(clearedHistory, 1);
      expect(model.activeChannelFilterCount, 2);
      await tester.tap(find.byTooltip('Clear channel filters'));
      await tester.pump();
      expect(model.activeChannelFilterCount, 0);
      expect(model.filter, GuideFilter.all);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
}
