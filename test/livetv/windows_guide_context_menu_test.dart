import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/livetv/live_tv_guide_screen.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements MediaServerClient {}
class _LiveApi extends Mock implements LiveTvApi {}
class _Playback extends Mock implements PlaybackManager {}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<PreferenceStore>(store);
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    final playback = _Playback();
    when(() => playback.backend).thenReturn(null);
    when(() => playback.backendChangedStream).thenAnswer((_) => const Stream<PlayerBackend>.empty());
    GetIt.instance.registerSingleton<PlaybackManager>(playback);
    final client = _Client();
    final api = _LiveApi();
    when(() => client.liveTvApi).thenReturn(api);
    when(() => client.serverType).thenReturn(ServerType.jellyfin);
    when(() => client.userId).thenReturn('windows-test-user');
    when(() => client.baseUrl).thenReturn('http://guide-test');
    when(() => api.getChannels(
      startIndex: any(named: 'startIndex'), limit: any(named: 'limit'),
      sortBy: any(named: 'sortBy'), sortOrder: any(named: 'sortOrder'),
      fields: any(named: 'fields'), enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
      userId: any(named: 'userId'),
    )).thenAnswer((_) async => {'Items': [
      {'Id': 'usa', 'Name': 'USA Network', 'ChannelNumber': '100',
       'ImageTags': <String, dynamic>{}, 'UserData': {'IsFavorite': false}},
      for (var i = 1; i <= 2; i++)
        {'Id': 'channel$i', 'Name': 'Other $i', 'ChannelNumber': '${100 + i}',
         'ImageTags': <String, dynamic>{}, 'UserData': {'IsFavorite': false}},
    ]});
    when(() => api.getGuide(
      startDate: any(named: 'startDate'), endDate: any(named: 'endDate'),
      channelIds: any(named: 'channelIds'), fields: any(named: 'fields'),
      enableTotalRecordCount: any(named: 'enableTotalRecordCount'),
      enableImages: any(named: 'enableImages'), enableUserData: any(named: 'enableUserData'),
      userId: any(named: 'userId'),
    )).thenAnswer((_) async => {'Items': <Map<String, dynamic>>[]});
    GetIt.instance.registerSingleton<MediaServerClient>(client);
  });
  tearDown(() async => GetIt.instance.reset());

  testWidgets('Windows right click and Shift F10 open channel actions; Escape restores row', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LiveTvGuideScreen(),
    ));
    await tester.pumpAndSettle();
    final channelFocus = tester.widgetList<Focus>(find.byType(Focus))
      .map((w) => w.focusNode).whereType<FocusNode>()
      .firstWhere((n) => n.debugLabel == 'GuideChannel:0');
    channelFocus.requestFocus();
    await tester.pumpAndSettle();
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton);
    await pointer.down(tester.getCenter(find.byKey(const ValueKey('guide-channel-usa'))));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(find.text('Watch Full Screen'), findsOneWidget);
    expect(find.text('Add Favorite'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Watch Full Screen'), findsNothing);
    expect(channelFocus.hasFocus, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Watch Full Screen'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(channelFocus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    final laterRow = tester.widgetList<Focus>(find.byType(Focus))
      .map((w) => w.focusNode).whereType<FocusNode>()
      .firstWhere((n) => n.debugLabel == 'GuideChannel:2');
    laterRow.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(laterRow.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(laterRow.hasFocus, isTrue, reason: 'Controls must restore the previous channel, not row zero; actual ${FocusManager.instance.primaryFocus?.debugLabel}');
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
}
