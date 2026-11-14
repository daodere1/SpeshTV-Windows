import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/blocked_content_gate.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/data/services/discord_request_bridge_io.dart';

class _Items extends Fake implements ItemsApi {
  @override
  Future<Map<String, dynamic>> getItem(
    String id, {
    String? mediaSourceId,
    String? fields,
  }) async => {'Id': id, 'Name': 'Movie $id', 'Type': 'Movie'};
}

class _Client extends Fake implements MediaServerClient {
  @override
  final itemsApi = _Items();
}

class _Factory extends Fake implements MediaServerClientFactory {
  @override
  String serverIdOf(MediaServerClient client) => 'server';
}

class _Gate extends Fake implements BlockedContentGate {
  bool blocked = false;
  @override
  Future<bool> isBlocked(AggregatedItem item) async => blocked;
}

class _Manager extends Fake implements PlaybackManager {
  @override
  final queueService = QueueService();
  @override
  final state = PlayerState();
  @override
  bool autoAdvanceEnabled = false;
  StreamResolutionResult? resolution;
  int starts = 0;
  @override
  StreamResolutionResult? get currentResolution => resolution;
  @override
  PlaybackBringupState get bringupState => const PlaybackBringupState.idle();
  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #playItems) {
      starts++;
      queueService.setQueue(List<dynamic>.from(call.positionalArguments.first));
      resolution = StreamResolutionResult(
        streamUrl: 'https://example.test/movie',
        mediaSourceId: 'source',
        playSessionId: 'session',
        playMethod: StreamPlayMethod.directPlay,
      );
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  test('idle request starts once; paused requests queue; retries and blocked items do not mutate queue', () async {
    final getIt = GetIt.instance;
    final manager = _Manager();
    final gate = _Gate();
    getIt.registerSingleton<MediaServerClient>(_Client());
    getIt.registerSingleton<MediaServerClientFactory>(_Factory());
    getIt.registerSingleton<PlaybackManager>(manager);
    getIt.registerSingleton<BlockedContentGate>(gate);
    const token = 'test-secret-long-enough-for-connection-token';
    var opens = 0;
    final bridge = DiscordRequestBridge(
      port: 0,
      readToken: () async => token,
      writeToken: (_) async {},
      openPlayer: () async {
        opens++;
      },
    );
    await bridge.setEnabled(true);
    final http = HttpClient();
    try {
      Future<(int, Map)> request(String item, String receipt) async {
        final req = await http.postUrl(
          Uri.parse('http://127.0.0.1:${bridge.boundPort}/request'),
        );
        req.headers.set('Authorization', 'Bearer $token');
        req.write(jsonEncode({'itemId': item, 'requestId': receipt}));
        final res = await req.close();
        return (
          res.statusCode,
          jsonDecode(await utf8.decoder.bind(res).join()) as Map,
        );
      }

      final first = await request('first', 'first-receipt');
      expect(first.$1, 200);
      expect(first.$2['action'], 'playing');
      expect(manager.starts, 1);
      expect(opens, 1);
      // isPlaying remains false: paused playback is still occupied.
      final two = await Future.wait([
        request('second', 'second-receipt'),
        request('third', 'third-receipt'),
      ]);
      expect(two.every((value) => value.$2['action'] == 'queued'), true);
      expect(manager.starts, 1);
      expect(manager.queueService.length, 3);
      await request('second', 'second-receipt');
      expect(manager.queueService.length, 3);
      expect((await request('second', 'different-receipt')).$1, 400);
      gate.blocked = true;
      expect((await request('blocked', 'blocked-receipt')).$1, 400);
      expect(manager.queueService.length, 3);
      expect(manager.autoAdvanceEnabled, true);
    } finally {
      http.close(force: true);
      await bridge.setEnabled(false);
      bridge.dispose();
      manager.queueService.dispose();
      manager.state.dispose();
      await getIt.reset();
    }
  });
}
