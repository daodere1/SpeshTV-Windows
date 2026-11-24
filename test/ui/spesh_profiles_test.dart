import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/data/services/spesh_profile_service.dart';
import 'package:moonfin/ui/screens/auth/spesh_profiles_screen.dart';
import 'package:moonfin/ui/widgets/spesh_profile_avatar.dart';

const owner = SpeshProfileOwner(
  serverId: 'server',
  userId: 'owner',
  baseUrl: 'https://test.invalid',
  token: 'owner-token',
);
const primary = SpeshViewingProfile(
  id: 'main',
  name: 'Profile 1',
  avatar: 'blue',
  isPrimary: true,
);

class _Api extends Fake implements SpeshProfilesApi {
  List<SpeshViewingProfile> profiles = [primary];
  bool unavailable = false;
  int? failureStatus = 404;
  int saves = 0;
  @override
  SpeshProfileOwner get owner => const SpeshProfileOwner(
    serverId: 'server',
    userId: 'owner',
    baseUrl: 'https://test.invalid',
    token: 'owner-token',
  );
  @override
  Future<List<SpeshViewingProfile>> list() async {
    if (unavailable)
      throw DioException(
        requestOptions: RequestOptions(path: '/Spesh/Profiles'),
        response: failureStatus == null
            ? null
            : Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: failureStatus,
              ),
      );
    return profiles;
  }

  @override
  Future<SpeshProfileSelection> select(SpeshViewingProfile p) async =>
      SpeshProfileSelection(
        p,
        p.isPrimary ? 'owner' : 'child',
        p.isPrimary ? 'owner-token' : 'child-token',
      );
  @override
  Future<void> save({
    SpeshViewingProfile? profile,
    required String name,
    required String avatar,
  }) async {
    saves++;
  }
}

class _Session extends Fake implements SessionRepository {
  final selections = <String>[];
  int continues = 0, logouts = 0;
  @override
  Future<void> activateSpeshProfile(
    SpeshProfileSelection s, {
    required SpeshProfileOwner expectedOwner,
  }) async {
    selections.add(s.profile.id);
  }

  @override
  Future<void> continueWithSpeshOwner() async {
    continues++;
  }

  @override
  Future<void> destroyCurrentSession({bool tokenKnownInvalid = false}) async {
    logouts++;
  }
}

void main() {
  testWidgets('avatar tiles override circular theme and align with Add', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: const CircleBorder()),
      )),
      home: SpeshProfilesScreen(api: _Api(), session: _Session()),
    ));
    await t.pumpAndSettle();
    final profile = find.ancestor(of: find.byType(SpeshProfileAvatar),
        matching: find.byType(OutlinedButton));
    final add = find.ancestor(of: find.byIcon(Icons.add),
        matching: find.byType(OutlinedButton));
    for (final finder in [profile, add]) {
      final button = t.widget<OutlinedButton>(finder);
      expect(button.style!.shape!.resolve({}), isA<RoundedRectangleBorder>());
      expect(t.getSize(finder), const Size.square(130));
    }
    expect(t.getTopLeft(profile).dy, t.getTopLeft(add).dy);
    await t.tap(find.text('Manage profiles'));
    await t.pumpAndSettle();
    await t.tap(profile);
    await t.pumpAndSettle();
    final choices = find.descendant(of: find.byType(AlertDialog),
        matching: find.byType(OutlinedButton));
    expect(choices, findsNWidgets(8));
    for (final element in choices.evaluate()) {
      final button = element.widget as OutlinedButton;
      expect(button.style!.shape!.resolve({}), isA<RoundedRectangleBorder>());
    }
  });

  Future<void> open(WidgetTester t, _Api api, _Session session) async {
    await t.pumpWidget(
      MaterialApp(
        home: SpeshProfilesScreen(api: api, session: session),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'cold picker requires explicit selection and supports keyboard Enter',
    (t) async {
      final api = _Api(), session = _Session();
      await open(t, api, session);
      expect(find.text('Who’s watching?'), findsOneWidget);
      expect(session.selections, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(session.selections, ['main']);
    },
  );
  testWidgets(
    'three profiles hide Add; editing has eight avatars and Escape cancels',
    (t) async {
      final api = _Api()
        ..profiles = [
          primary,
          const SpeshViewingProfile(
            id: 'two',
            name: 'Two',
            avatar: 'gold',
            isPrimary: false,
          ),
          const SpeshViewingProfile(
            id: 'three',
            name: 'Three',
            avatar: 'teal',
            isPrimary: false,
          ),
        ];
      final session = _Session();
      await open(t, api, session);
      expect(find.text('Add profile'), findsNothing);
      await t.tap(find.text('Manage profiles'));
      await t.pumpAndSettle();
      await t.tap(find.byType(OutlinedButton).first);
      await t.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.byType(SpeshProfileAvatar), findsNWidgets(11));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Edit profile'), findsNothing);
      await t.tap(find.byType(OutlinedButton).first);
      await t.pumpAndSettle();
      await t.sendKeyEvent(
        LogicalKeyboardKey.gameButtonB,
        platform: 'android',
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await t.pumpAndSettle();
      expect(find.text('Edit profile'), findsNothing);
      expect(api.saves, 0);
      expect(session.selections, isEmpty);
    },
  );
  testWidgets(
    'older Core offers account compatibility without selecting a child',
    (t) async {
      final api = _Api()..unavailable = true;
      final session = _Session();
      await open(t, api, session);
      expect(find.text('Continue with account'), findsOneWidget);
      await t.tap(find.text('Continue with account'));
      await t.pumpAndSettle();
      expect(session.continues, 1);
      expect(session.selections, isEmpty);
    },
  );
  testWidgets('Sign out leaves picker through the startup route', (t) async {
    final api = _Api(), session = _Session();
    final router = GoRouter(
      initialLocation: '/profiles',
      routes: [
        GoRoute(
          path: '/profiles',
          builder: (_, __) => SpeshProfilesScreen(api: api, session: session),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Signed out')),
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Sign out'));
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(session.logouts, 1);
    expect(find.text('Signed out'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    router.dispose();
  });
  testWidgets('network failure offers only the original account fallback', (
    t,
  ) async {
    final api = _Api()
      ..unavailable = true
      ..failureStatus = null;
    final session = _Session();
    await open(t, api, session);
    expect(find.text('Continue with account'), findsOneWidget);
    await t.tap(find.text('Continue with account'));
    await t.pumpAndSettle();
    expect(session.continues, 1);
    expect(session.selections, isEmpty);
  });
  testWidgets('authentication/policy refusal cannot bypass profile selection', (
    t,
  ) async {
    final api = _Api()
      ..unavailable = true
      ..failureStatus = 403;
    final session = _Session();
    await open(t, api, session);
    expect(find.text('Continue with account'), findsNothing);
    expect(session.continues, 0);
  });
}
