import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/spesh_profile_service.dart';
import 'package:server_core/server_core.dart';

const owner = SpeshProfileOwner(
  serverId: 'server',
  userId: 'owner',
  baseUrl: 'https://server.invalid/jellyfin/',
  token: 'owner-token',
);
const device = DeviceInfo(
  id: 'windows-device',
  name: 'Windows',
  appName: 'SpeshTV',
  appVersion: '3.1.0',
);
const mainProfile = SpeshViewingProfile(
  id: 'main',
  name: 'Profile 1',
  avatar: 'blue',
  isPrimary: true,
);
const child = SpeshViewingProfile(
  id: 'two',
  name: 'Two',
  avatar: 'gold',
  isPrimary: false,
);
void main() {
  test(
    'catalogue and both selections always use owner auth with DeviceId',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              final primary = request.path.endsWith('/main/Select');
              final profile = primary ? mainProfile : child;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: request.method == 'GET'
                      ? {
                          'profiles': [
                            {
                              'id': 'main',
                              'name': 'Profile 1',
                              'avatar': 'blue',
                              'isPrimary': true,
                            },
                          ],
                          'maximumProfiles': 3,
                        }
                      : {
                          'profile': {
                            'id': profile.id,
                            'name': profile.name,
                            'avatar': profile.avatar,
                            'isPrimary': profile.isPrimary,
                          },
                          'userId': primary ? 'owner' : 'managed-two',
                          'accessToken': primary ? null : 'child-token',
                        },
                ),
              );
            },
          ),
        );
      final api = SpeshProfilesApi(owner, device, dio: dio);
      expect((await api.list()).single.isPrimary, true);
      final selected = await api.select(child);
      expect(selected.userId, 'managed-two');
      expect(selected.token, 'child-token');
      final restored = await api.select(mainProfile);
      expect(restored.userId, 'owner');
      expect(restored.token, 'owner-token');
      for (final request in requests) {
        expect(request.headers['Authorization'], contains('owner-token'));
        expect(request.headers['Authorization'], contains('windows-device'));
        expect(
          request.headers['Authorization'],
          isNot(contains('child-token')),
        );
        expect(
          request.path,
          startsWith('https://server.invalid/jellyfin/Spesh/Profiles'),
        );
      }
      api.dispose();
    },
  );
  test(
    'malformed identity or owner token for secondary profile is rejected',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) => h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'profile': {
                    'id': 'two',
                    'name': 'Two',
                    'avatar': 'gold',
                    'isPrimary': false,
                  },
                  'userId': 'managed-two',
                  'accessToken': 'owner-token',
                },
              ),
            ),
          ),
        );
      final api = SpeshProfilesApi(owner, device, dio: dio);
      await expectLater(api.select(child), throwsStateError);
      api.dispose();
    },
  );
  test('invalid names/avatar never make management requests', () async {
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            requests++;
            h.resolve(Response(requestOptions: r, statusCode: 200));
          },
        ),
      );
    final api = SpeshProfilesApi(owner, device, dio: dio);
    for (final name in ['', List.filled(25, 'x').join()]) {
      await expectLater(
        api.save(name: name, avatar: 'blue'),
        throwsArgumentError,
      );
    }
    await expectLater(
      api.save(name: 'Valid', avatar: 'kids-policy'),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.dispose();
  });
}
