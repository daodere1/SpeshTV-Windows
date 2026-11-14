import 'package:flutter_test/flutter_test.dart';

import '../../lib/util/youtube_embed_identity.dart';

void main() {
  test('referrer identifies the actual installed tester or store app', () {
    for (final id in [
      'dev.speshmedia.moonfin',
      'com.speshmedia.speshcast',
      'com.speshmedia.speshcast.tv',
    ]) {
      expect(youtubeEmbedOrigin(id), 'https://$id');
    }
  });
  test(
    'normalizes app identity without leaking user or server information',
    () {
      expect(
        youtubeEmbedOrigin(' COM.SPESHMEDIA.SPESHCAST '),
        'https://com.speshmedia.speshcast',
      );
      for (final id in [
        '',
        'https://example.com',
        'user:token@server',
        'a/b',
        'app\r\nHeader: value',
      ]) {
        expect(() => youtubeEmbedOrigin(id), throwsArgumentError);
      }
    },
  );
}
