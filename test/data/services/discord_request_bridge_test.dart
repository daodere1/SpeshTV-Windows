import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/discord_request_bridge_io.dart';

void main() {
  test('bridge binds loopback, rejects unauthorized and browser calls, and dispatches confirmed IDs', () async {
    final calls = <Map<String, dynamic>>[];
    const token = 'test-secret-with-at-least-thirty-two-characters';
    final bridge = DiscordRequestBridge(
      port: 0,
      readToken: () async => token,
      writeToken: (_) async {},
      handler: (path, data) async {
        calls.add({'path': path, ...data});
        return {'action': 'queued'};
      },
    );
    await bridge.setEnabled(true);
    final client = HttpClient();
    try {
      Future<(int, Map)> request({
        String? auth,
        String? origin,
        bool post = false,
      }) async {
        final req = await client.openUrl(
          post ? 'POST' : 'GET',
          Uri.parse(
            'http://127.0.0.1:${bridge.boundPort}/${post ? 'request' : 'status'}',
          ),
        );
        if (auth != null) req.headers.set('Authorization', auth);
        if (origin != null) req.headers.set('Origin', origin);
        if (post)
          req.write(
            jsonEncode({'itemId': 'selected-id', 'requestId': 'receipt'}),
          );
        final response = await req.close();
        return (
          response.statusCode,
          jsonDecode(await utf8.decoder.bind(response).join()) as Map,
        );
      }

      expect((await request()).$1, 401);
      expect((await request(auth: 'Bearer wrong')).$1, 401);
      expect(
        (await request(
          auth: 'Bearer $token',
          origin: 'https://example.com',
        )).$1,
        401,
      );
      expect(calls, isEmpty);
      expect((await request(auth: 'Bearer $token', post: true)).$1, 200);
      expect(calls.single['itemId'], 'selected-id');
      expect(calls.single['requestId'], 'receipt');
    } finally {
      client.close(force: true);
      await bridge.setEnabled(false);
      bridge.dispose();
    }
  });
}
