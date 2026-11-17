import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/item_mutation_repository.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_section_modal.dart';
import 'package:moonfin/ui/widgets/media_card.dart';

class _Client extends Mock implements MediaServerClient {}

class _Mutations extends Mock implements ItemMutationRepository {}

class _Images extends Mock implements ImageApi {}

void main() {
  for (final activation in ['right click', 'Menu', 'Shift F10', 'long press']) {
    for (final admin in [false, true]) {
      testWidgets(
        'episode $activation actions respect admin=$admin and keep modal open',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final store = PreferenceStore();
          await store.init();
          final prefs = UserPreferences(store);
          final client = _Client();
          when(() => client.serverType).thenReturn(ServerType.emby);
          final mutations = _Mutations();
          when(() => mutations.setPlayed('episode', isPlayed: true))
              .thenAnswer((_) async {});
          final users = UserRepository();
          users.setCurrentUser(
            PrivateUser(
              id: 'user',
              name: 'Test',
              serverId: 'server',
              accessToken: 'test',
              lastUsed: DateTime(2026),
              isAdministrator: admin,
            ),
          );
          GetIt.instance.registerSingleton<MediaServerClient>(client);
          GetIt.instance.registerSingleton<ItemMutationRepository>(mutations);
          GetIt.instance.registerSingleton<UserRepository>(users);
          GetIt.instance.registerSingleton<UserPreferences>(prefs);
          addTearDown(() => GetIt.instance.reset());
          var opened = 0;
          var changed = 0;
          const episode = AggregatedItem(
            id: 'episode',
            serverId: 'server',
            rawData: {
              'Type': 'Episode',
              'Name': 'Test episode',
              'UserData': {'Played': false},
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () => SpotlightSectionModal.show(
                      context,
                      title: 'More Episodes',
                      sections: [
                        SpotlightModalSection(
                          fillsViewport: true,
                          builder: (context, focus) =>
                              SpotlightMediaGridSection(
                                items: const [episode],
                                bounded: true,
                                imageApi: _Images(),
                                prefs: prefs,
                                onItemTap: (_) {
                                  opened++;
                                },
                                onItemChanged: () {
                                  changed++;
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final card = find.byType(MediaCard);
          if (activation == 'right click') {
            final gesture = await tester.startGesture(
              tester.getCenter(card),
              kind: PointerDeviceKind.mouse,
              buttons: kSecondaryMouseButton,
            );
            await gesture.up();
          } else if (activation == 'long press') {
            await tester.longPress(card);
          } else {
            final focus = find.descendant(
              of: card,
              matching: find.byType(Focus),
            );
            tester.widget<Focus>(focus.first).focusNode?.requestFocus();
            // Focus the card through its own Focus widget when it owns its node.
            Focus.of(
              tester.element(
                find
                    .descendant(
                      of: card,
                      matching: find.byType(GestureDetector),
                    )
                    .first,
              ),
            ).requestFocus();
            await tester.pump();
            if (activation == 'Menu') {
              await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
            } else {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.f10);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
            }
          }
          await tester.pumpAndSettle();
          expect(find.text('Mark as Watched'), findsOneWidget);
          expect(
            find.text('Change Artwork'),
            admin ? findsOneWidget : findsNothing,
          );
          expect(opened, 0);
          await tester.tap(find.text('Mark as Watched'));
          await tester.pumpAndSettle();
          verify(() => mutations.setPlayed('episode', isPlayed: true))
              .called(1);
          expect(changed, 1);
          expect(find.text('More Episodes'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
