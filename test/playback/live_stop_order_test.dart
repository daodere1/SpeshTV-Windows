import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:playback_core/playback_core.dart';
import 'package:playback_jellyfin/src/play_session_service.dart';
import 'package:server_core/server_core.dart';

class _Api extends Fake implements PlaybackApi {
  final calls = <String>[];
  final stopped = Completer<void>();
  @override
  Future<void> closeLiveStream(String id) async { calls.add('close'); }
  @override
  Future<void> reportPlaybackStopped(Map<String, dynamic> info) {
    calls.add('report');
    return stopped.future;
  }
}

class _Client extends Fake implements MediaServerClient {
  _Client(this.api);
  final _Api api;
  @override
  PlaybackApi get playbackApi => api;
}

void main() {
  for (final release in [true, false]) {
    test('blocked stop report releases live stream first: $release', () async {
      final api = _Api();
      final service = PlaySessionService(_Client(api));
      final stop = service.onPlaybackStop(
        {'Id': 'channel', 'Type': 'TvChannel'},
        const StreamResolutionResult(
          streamUrl: 'http://localhost/live', mediaSourceId: 'channel',
          liveStreamId: 'old-stream', playMethod: StreamPlayMethod.transcode,
        ),
        Duration.zero, releaseLiveStream: release,
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, release ? ['close', 'report'] : ['report']);
      api.stopped.complete();
      await stop;
      expect(api.calls, release ? ['close', 'report'] : ['report']);
    });
  }
}
