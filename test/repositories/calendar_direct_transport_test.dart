import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/data/repositories/seerr_repository.dart';
import 'package:server_core/server_core.dart';

class _Client extends Mock implements MediaServerClient {}
class _Store extends Mock implements PreferenceStore {}
class _Session extends Mock implements SessionRepository {}

void main() {
  test('calendar uses Jellyfin authorization without a Seerr status/login probe', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    final auth = <String?>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      auth.add(request.headers.value('Authorization'));
      request.response.headers.contentType = ContentType.json;
      request.response.write('[{"airDateUtc":"2026-11-15T02:00:00Z"}]');
      await request.response.close();
    });
    final client = _Client();
    when(() => client.baseUrl).thenReturn('http://127.0.0.1:${server.port}');
    when(() => client.accessToken).thenReturn('test-token');
    final repository = SeerrRepository(_Store(), _Session(), client);
    try {
      final result = await repository.getSonarrCalendar(start: '2026-11-01', end: '2026-12-01');
      expect(result.single['airDateUtc'], '2026-11-15T02:00:00Z');
      expect(paths, ['/Moonfin/Seerr/Sonarr/Calendar']);
      expect(auth.single, contains('test-token'));
    } finally {
      repository.close();
      await server.close(force: true);
    }
  });
}
