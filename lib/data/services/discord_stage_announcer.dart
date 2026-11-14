import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:server_core/server_core.dart';

import '../models/aggregated_item.dart';

/// Opt-in per launch. Uses a separate HTTP client with no app logging interceptors.
class DiscordStageAnnouncer extends ChangeNotifier {
  static const available = bool.fromEnvironment('SPESHTV_ANNOUNCEMENTS', defaultValue: true);
  static final instance = DiscordStageAnnouncer();
  static const _storageKey = 'speshtv_discord_stage_webhook';
  static const _roleKey = 'speshtv_discord_announcement_role';
  static const _storage = FlutterSecureStorage();

  final Dio _http;
  final Future<String?> Function() _readUrl;
  final Future<void> Function(String) _writeUrl;
  final Future<void> Function() _deleteUrl;
  final Future<String?> Function() _readRole;
  final Future<void> Function(String?) _writeRole;
  String? _roleId;
  String? get roleId => _roleId;
  String? _url;
  String? _lastItem;
  String? _lastFinishedItem;
  int _generation = 0;
  bool enabled = false;
  bool ready = false;
  String status = 'Announcements are off.';

  DiscordStageAnnouncer({
    Dio? http,
    Future<String?> Function()? readUrl,
    Future<void> Function(String)? writeUrl,
    Future<void> Function()? deleteUrl,
    Future<String?> Function()? readRole,
    Future<void> Function(String?)? writeRole,
  }) : _http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 8),
               followRedirects: false,
             ),
           ),
       _readUrl = readUrl ?? (() => _storage.read(key: _storageKey)),
       _writeUrl =
           writeUrl ?? ((url) => _storage.write(key: _storageKey, value: url)),
       _deleteUrl = deleteUrl ?? (() => _storage.delete(key: _storageKey)),
       _readRole = readRole ?? (() => _storage.read(key: _roleKey)),
       _writeRole =
           writeRole ??
           ((role) => role == null
               ? _storage.delete(key: _roleKey)
               : _storage.write(key: _roleKey, value: role));

  bool get configured => _url != null;

  static String? normalizeWebhook(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !{'discord.com', 'discordapp.com'}.contains(uri.host)) {
      return null;
    }
    if (!RegExp(r'^/api(?:/v\d+)?/webhooks/\d+/[A-Za-z0-9_-]+/?$')
        .hasMatch(uri.path)) {
      return null;
    }
    return Uri(
      scheme: 'https',
      host: 'discord.com',
      path: uri.path.replaceFirst(RegExp(r'/$'), ''),
    ).toString();
  }

  static bool validRoleId(String value) {
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(value)) return false;
    return BigInt.parse(value) <= BigInt.parse('18446744073709551615');
  }

  Future<void> saveRole(String value) async {
    final role = value.trim();
    if (role.isNotEmpty && !validRoleId(role)) {
      throw const DiscordAnnouncementError(
        'Enter a numeric Discord role ID, or leave it blank for no pings.',
      );
    }
    try {
      await _writeRole(role.isEmpty ? null : role);
    } catch (_) {
      throw const DiscordAnnouncementError(
        'Could not save role customization. Try again.',
      );
    }
    _roleId = role.isEmpty ? null : role;
    status = _roleId == null
        ? 'Customization saved. Role pings are off.'
        : 'Customization saved. Announcements will mention the selected role.';
    notifyListeners();
  }

  Future<void> load() async {
    if (ready) return;
    try {
      final saved = await _readUrl();
      _url = saved == null ? null : normalizeWebhook(saved);
      final role = await _readRole();
      _roleId = role != null && validRoleId(role) ? role : null;
    } catch (_) {
      status = 'Could not read the saved webhook. Save it again.';
    }
    ready = true;
    notifyListeners();
  }

  Future<void> save(String value) async {
    final url = normalizeWebhook(value);
    if (url == null)
      throw const DiscordAnnouncementError(
        'Enter a valid Discord webhook URL.',
      );
    try {
      final response = await _http.get<dynamic>(url);
      final data = response.data;
      if (data is! Map ||
          !RegExp(r'^\d+$').hasMatch(data['channel_id']?.toString() ?? '')) {
        throw const DiscordAnnouncementError(
          'Discord did not return a valid channel for this webhook. Check the webhook URL.',
        );
      }
      await _writeUrl(url);
      _url = url;
      ready = true;
      setEnabled(false);
      status = 'Webhook saved and verified. Announcements go to its configured channel.';
      notifyListeners();
    } on DiscordAnnouncementError {
      rethrow;
    } on DioException {
      throw const DiscordAnnouncementError(
        'Could not verify the webhook with Discord. Check the URL and your connection.',
      );
    } catch (_) {
      throw const DiscordAnnouncementError(
        'Could not securely save the webhook. Try again.',
      );
    }
  }

  Future<void> forget() async {
    try {
      await _deleteUrl();
      await _writeRole(null);
    } catch (_) {
      throw const DiscordAnnouncementError(
        'Could not remove the saved webhook. Try again.',
      );
    }
    _url = null;
    _roleId = null;
    setEnabled(false);
    status = 'Webhook removed.';
    notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = available && value && configured;
    _lastItem = null;
    _lastFinishedItem = null;
    _generation++;
    status = enabled
        ? 'Ready to announce the next movie or episode.'
        : 'Announcements are off.';
    notifyListeners();
  }

  static Map<String, dynamic>? metadata(dynamic item) {
    if (item is AggregatedItem)
      return {...item.rawData, 'ServerId': item.serverId};
    if (item is ServerItem)
      return {
        'Id': item.id,
        'ServerId': item.serverId,
        'Name': item.name,
        'Type': item.type == ItemType.movie
            ? 'Movie'
            : item.type == ItemType.episode
            ? 'Episode'
            : '',
        'ProductionYear': item.productionYear,
        'SeriesName': item.seriesName,
        'ParentIndexNumber': item.parentIndexNumber,
        'IndexNumber': item.indexNumber,
      };
    if (item is Map<String, dynamic>) return item;
    return null;
  }

  static String? announcement(Map<String, dynamic> item) {
    final name = item['Name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    if (item['Type'] == 'Movie') {
      final year = item['ProductionYear'];
      return '🎬 Now playing: $name${year == null ? '' : ' ($year)'}';
    }
    if (item['Type'] == 'Episode') {
      final series = item['SeriesName']?.toString().trim() ?? '';
      final season = item['ParentIndexNumber'];
      final episode = item['IndexNumber'];
      final number =
          '${season == null ? '' : 'S${season.toString().padLeft(2, '0')}'}${episode == null ? '' : 'E${episode.toString().padLeft(2, '0')}'}';
      return '📺 Now playing: ${[series, number, name].where((part) => part.isNotEmpty).join(' — ')}';
    }
    return null;
  }

  Future<void> playbackStarted(dynamic item) async {
    if (!enabled || _url == null) return;
    final data = metadata(item);
    if (data == null) return;
    final content = announcement(data);
    final id = data['Id']?.toString();
    if (content == null || id == null || id.isEmpty) return;
    final key = '${data['ServerId'] ?? ''}:$id';
    if (_lastItem == key) return;
    _lastFinishedItem = null;
    _lastItem =
        key; // Reserve before awaiting: restarts cannot race a second post.
    final generation = _generation;
    await _send(content, generation: generation);
  }

  Future<void> playbackCompleted(dynamic item) async {
    if (!enabled || _url == null) return;
    final data = metadata(item);
    if (data == null) return;
    final playing = announcement(data);
    final id = data['Id']?.toString();
    if (playing == null || id == null || id.isEmpty) return;
    final key = '${data['ServerId'] ?? ''}:$id';
    if (_lastFinishedItem == key) return;
    _lastFinishedItem = key;
    await _send(
      playing.replaceFirst('Now playing:', 'Finished:'),
      generation: _generation,
      mentionRole: false,
    );
  }

  Future<void> sendTest() async {
    if (_url == null)
      throw const DiscordAnnouncementError('Save a webhook first.');
    final sent = await _send(
      '✅ SpeshTV announcements are connected to this channel.',
    );
    if (!sent) throw DiscordAnnouncementError(status);
  }

  Future<bool> _send(
    String content, {
    int? generation,
    bool mentionRole = true,
  }) async {
    final url = _url;
    if (url == null) return false;
    try {
      final role = mentionRole ? _roleId : null;
      final message = '${role == null ? '' : '<@&$role>\n'}$content';
      final payload = {
        'content': message.length > 1900 ? message.substring(0, 1900) : message,
        'allowed_mentions': {
          'parse': <String>[],
          'roles': <String>[if (role != null) role],
          'users': <String>[],
          'replied_user': false,
        },
      };
      await _http.post<dynamic>(
        url,
        data: payload,
        queryParameters: {'wait': 'true'},
      );
      if (generation == null || generation == _generation) {
        status = 'Announcement sent.';
        notifyListeners();
      }
      return true;
    } catch (_) {
      // Never log exceptions: their request URL contains the webhook secret.
      if (generation == null || generation == _generation) {
        status = 'Discord announcement failed. Check the webhook and connection; playback continues.';
        notifyListeners();
      }
      return false;
    }
  }
}

class DiscordAnnouncementError implements Exception {
  final String message;
  const DiscordAnnouncementError(this.message);
  @override
  String toString() => message;
}
