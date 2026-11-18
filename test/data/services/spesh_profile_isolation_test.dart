import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/auth/models/server.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/auth/store/authentication_store.dart';
import 'package:moonfin/auth/store/credential_store.dart';
import 'package:moonfin/data/repositories/multi_server_repository.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/data/services/user_data_sync.dart';
import 'package:moonfin/data/models/aggregated_item.dart';

class _Session extends Fake implements SessionRepository {
  bool managed = false;
  @override
  bool get isSpeshManagedProfile => managed;
  @override
  String? get activeServerId => 'server';
  @override
  String? get activeUserId => managed ? 'managed-two' : 'owner';
}

class _Client extends Fake implements MediaServerClient {
  @override
  String? userId = 'owner';
  @override
  String? accessToken = 'owner-token';
}

class _Factory extends Fake implements MediaServerClientFactory {
  final client = _Client();
  @override
  MediaServerClient? getClientIfExists(String id) => client;
  @override
  MediaServerClient getClient({
    required String serverId,
    required ServerType serverType,
    required String baseUrl,
  }) => client;
}

class _Store extends Fake implements AuthenticationStore {
  int userReads = 0;
  @override
  List<Server> getServers() => [
    Server(
      id: 'server',
      name: 'Test',
      address: 'https://test.invalid',
      version: '12',
      serverType: ServerType.jellyfin,
      dateAdded: DateTime(2026),
    ),
  ];
  @override
  List<PrivateUser> getUsers(String id) {
    userReads++;
    return [
      PrivateUser(
        id: 'owner',
        name: 'Owner',
        serverId: 'server',
        accessToken: 'owner-token',
        lastUsed: DateTime(2026),
      ),
    ];
  }
}

class _Credentials extends Fake implements CredentialStore {
  @override
  Future<String?> getToken(String id) async => 'owner-token';
}

class _Api extends Mock implements ItemsApi {}

class _MockClient extends Mock implements MediaServerClient {}

void main() {
  test(
    'cached owner and absent saved child cannot overwrite managed identity',
    () async {
      final session = _Session(), factory = _Factory(), store = _Store();
      final repo = MultiServerRepository(
        store,
        _Credentials(),
        factory,
        session,
      );
      expect((await repo.getLoggedInServers()).single.userId, 'owner');
      final reads = store.userReads;
      session.managed = true;
      factory.client.userId = 'managed-two';
      factory.client.accessToken = 'child-token';
      final child = (await repo.getLoggedInServers()).single;
      expect(child.userId, 'managed-two');
      expect(child.client.accessToken, 'child-token');
      expect(store.userReads, reads);
      expect(factory.client.userId, 'managed-two');
      session.managed = false;
      factory.client.userId = 'owner';
      factory.client.accessToken = 'owner-token';
      expect((await repo.getLoggedInServers()).single.userId, 'owner');
    },
  );
  test(
    'an old history response cannot populate the newly selected profile',
    () async {
      final sync = UserDataSync(), client = _MockClient(), api = _Api();
      final response = Completer<Map<String, dynamic>>();
      when(() => client.itemsApi).thenReturn(api);
      when(
        () => api.getItems(
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
          recursive: true,
          limit: any(named: 'limit'),
          enableTotalRecordCount: false,
        ),
      ).thenAnswer((_) => response.future);
      final request = sync.refreshFromServer(client, ['movie']);
      sync.reset();
      response.complete({
        'Items': [
          {
            'Id': 'movie',
            'UserData': {'Played': true, 'PlaybackPositionTicks': 123},
          },
        ],
      });
      await request;
      expect(sync.applyAll([]), isEmpty);
      expect(
        sync
            .apply(
              const AggregatedItem(
                id: 'movie',
                serverId: 'server',
                rawData: {
                  'Type': 'Movie',
                  'UserData': {'Played': false},
                },
              ),
            )
            .isPlayed,
        false,
      );
      sync.dispose();
    },
  );
}
