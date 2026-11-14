import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/discord_stage_announcer.dart';

class _DiscordAdapter implements HttpClientAdapter {
  final posts = <RequestOptions>[];
  String channel = '1556007978010681495';
  bool failPost = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.method == 'POST') {
      posts.add(options);
      if (failPost) return ResponseBody.fromString('{}', 500);
    }
    return ResponseBody.fromString(
      '{"channel_id":"$channel"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const url = 'https://discord.com/api/webhooks/123456/secret_token';
  late _DiscordAdapter adapter;
  late DiscordStageAnnouncer service;
  late String? saved;
  late String? savedRole;
  setUp(() {
    saved = null;
    savedRole = null;
    adapter = _DiscordAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    service = DiscordStageAnnouncer(
      http: dio,
      readRole: () async => savedRole,
      writeRole: (role) async {
        savedRole = role;
      },
      readUrl: () async => saved,
      writeUrl: (value) async {
        saved = value;
      },
      deleteUrl: () async {
        saved = null;
        savedRole = null;
      },
    );
  });
  tearDown(() => service.dispose());

  test(
    'accepts different channel IDs, stores URL, and remains off after loading',
    () async {
      await service.save(url);
      expect(saved, url);
      expect(service.enabled, false);
      final restored = DiscordStageAnnouncer(
        readUrl: () async => saved,
        readRole: () async => savedRole,
      );
      await restored.load();
      expect(restored.configured, true);
      expect(restored.enabled, false);
      restored.dispose();
      adapter.channel = '987654321098765432';
      await service.save(url);
      expect(saved, url);
      expect(service.configured, true);
      adapter.channel = '';
      await expectLater(
        service.save(url),
        throwsA(isA<DiscordAnnouncementError>()),
      );
    },
  );

  test(
    'posts each item once, includes episode data, and suppresses mentions',
    () async {
      await service.save(url);
      const movie = AggregatedItem(
        id: 'm',
        serverId: 'server',
        rawData: {
          'Id': 'm',
          'Type': 'Movie',
          'Name': 'Movie @everyone',
          'ProductionYear': 2026,
        },
      );
      await service.playbackStarted(movie);
      expect(adapter.posts, isEmpty);
      service.setEnabled(true);
      await Future.wait([
        service.playbackStarted(movie),
        service.playbackStarted(movie),
      ]);
      await service.playbackStarted(movie); // track switch or resume
      await service.playbackStarted({
        'Id': 'e1',
        'Type': 'Episode',
        'SeriesName': 'Show',
        'Name': 'Pilot',
        'ParentIndexNumber': 2,
        'IndexNumber': 3,
      });
      await service.playbackStarted({
        'Id': 't',
        'Type': 'Trailer',
        'Name': 'Trailer',
      });
      expect(adapter.posts, hasLength(2));
      expect(
        adapter.posts.first.data['content'],
        '🎬 Now playing: Movie @everyone (2026)',
      );
      expect(adapter.posts.first.data['allowed_mentions']['parse'], isEmpty);
      expect(
        adapter.posts.last.data['content'],
        '📺 Now playing: Show — S02E03 — Pilot',
      );
      service.setEnabled(false);
      await service.playbackStarted({
        'Id': 'e2',
        'Type': 'Episode',
        'Name': 'Next',
      });
      expect(adapter.posts, hasLength(2));
    },
  );

  test(
    'network failure never escapes playback, test reports it without secret',
    () async {
      await service.save(url);
      service.setEnabled(true);
      adapter.failPost = true;
      await service.playbackStarted({
        'Id': 'm',
        'Type': 'Movie',
        'Name': 'Movie',
      });
      expect(service.status, contains('failed'));
      expect(service.status, isNot(contains('secret_token')));
      await expectLater(
        service.sendTest(),
        throwsA(isA<DiscordAnnouncementError>()),
      );
    },
  );

  test(
    'optional role persists, pings only that role, and clears to no mentions',
    () async {
      const role = '987654321098765432';
      await service.save(url);
      await service.saveRole(' $role ');
      expect(savedRole, role);
      final restored = DiscordStageAnnouncer(
        readUrl: () async => saved,
        readRole: () async => savedRole,
      );
      await restored.load();
      expect(restored.roleId, role);
      expect(restored.enabled, false);
      restored.dispose();
      service.setEnabled(true);
      await service.playbackStarted({
        'Id': 'm',
        'Type': 'Movie',
        'Name': 'Movie @everyone <@123> <@&456>',
      });
      final payload = adapter.posts.last.data;
      expect(payload['content'], startsWith('<@&$role>\n🎬'));
      expect(payload['allowed_mentions']['parse'], isEmpty);
      expect(payload['allowed_mentions']['roles'], [role]);
      expect(payload['allowed_mentions']['users'], isEmpty);
      await service.sendTest();
      expect(adapter.posts.last.data['allowed_mentions']['roles'], [role]);
      await service.saveRole('');
      expect(savedRole, isNull);
      await service.sendTest();
      expect(adapter.posts.last.data['content'], isNot(startsWith('<@&')));
      expect(adapter.posts.last.data['allowed_mentions']['roles'], isEmpty);
      await service.saveRole(role);
      await service.forget();
      expect(service.roleId, isNull);
      expect(savedRole, isNull);
    },
  );

  test(
    'rejects invalid role IDs without changing saved customization',
    () async {
      const role = '987654321098765432';
      await service.saveRole(role);
      for (final invalid in [
        '@everyone',
        '<@&123>',
        'abc',
        '0',
        '-1',
        '18446744073709551616',
      ]) {
        await expectLater(
          service.saveRole(invalid),
          throwsA(isA<DiscordAnnouncementError>()),
        );
        expect(service.roleId, role);
        expect(savedRole, role);
      }
    },
  );

  test(
    'finished announcements never mention roles and duplicate ends are ignored',
    () async {
      await service.save(url);
      await service.saveRole('987654321098765432');
      final item = {
        'Id': 'm',
        'Type': 'Movie',
        'Name': 'Movie @everyone <@&123>',
      };
      await service.playbackCompleted(item);
      expect(adapter.posts, isEmpty);
      service.setEnabled(true);
      await service.playbackStarted(item);
      expect(adapter.posts.last.data['allowed_mentions']['roles'], [
        '987654321098765432',
      ]);
      await service.playbackCompleted(item);
      final end = adapter.posts.last.data;
      expect(end['content'], '🎬 Finished: Movie @everyone <@&123>');
      expect(end['allowed_mentions']['roles'], isEmpty);
      expect(end['allowed_mentions']['users'], isEmpty);
      expect(end['allowed_mentions']['parse'], isEmpty);
      await service.playbackCompleted(item);
      expect(adapter.posts, hasLength(2));
    },
  );

  test('rejects non-Discord URLs and normalizes away query parameters', () {
    expect(
      DiscordStageAnnouncer.normalizeWebhook(
        'https://example.com/api/webhooks/1/token',
      ),
      isNull,
    );
    expect(
      DiscordStageAnnouncer.normalizeWebhook(
        'http://discord.com/api/webhooks/1/token',
      ),
      isNull,
    );
    expect(DiscordStageAnnouncer.normalizeWebhook('$url?thread_id=42'), url);
  });
}
