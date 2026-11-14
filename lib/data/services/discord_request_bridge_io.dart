import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';

import '../models/aggregated_item.dart';
import 'blocked_content_gate.dart';
import 'media_server_client_factory.dart';
import '../../ui/navigation/app_router.dart';
import '../../ui/navigation/destinations.dart';

typedef RequestHandler = Future<Map<String, dynamic>> Function(
  String,
  Map<String, dynamic>,
);

/// Loopback-only, opt-in bridge. The bot never receives media server credentials.
class DiscordRequestBridge extends ChangeNotifier {
  static final instance = DiscordRequestBridge();
  static const endpoint = 'http://127.0.0.1:47653';
  static const _storage = FlutterSecureStorage();
  HttpServer? _server;
  String? _token;
  late final RequestHandler _handler;
  final Future<void> Function() _openPlayer;
  final Future<String?> Function() _readToken;
  final Future<void> Function(String) _writeToken;
  final int port;
  String status = 'Chat requests are off.';
  bool get enabled => _server != null;
  String? get token => _token;

  DiscordRequestBridge({
    RequestHandler? handler,
    Future<void> Function()? openPlayer,
    Future<String?> Function()? readToken,
    Future<void> Function(String)? writeToken,
    this.port = 47653,
  }) : _openPlayer = openPlayer ?? _defaultOpenPlayer,
       _readToken =
           readToken ??
           (() => _storage.read(key: 'speshtv_discord_bridge_token')),
       _writeToken =
           writeToken ??
           ((value) => _storage.write(
             key: 'speshtv_discord_bridge_token',
             value: value,
           )) {
    _handler = handler ?? _dispatch;
  }

  int? get boundPort => _server?.port;

  static Future<void> _defaultOpenPlayer() async {
    final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (currentPath != Destinations.videoPlayer) {
      unawaited(appRouter.push(Destinations.videoPlayer));
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!value) {
      final server = _server;
      _server = null;
      await server?.close(force: true);
      status = 'Chat requests are off.';
      notifyListeners();
      return;
    }
    if (enabled) return;
    try {
      _token = await _readToken();
      if (_token == null || _token!.length < 32) {
        final random = Random.secure();
        _token = base64Url.encode(
          List.generate(32, (_) => random.nextInt(256)),
        );
        await _writeToken(_token!);
      }
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server!.listen((request) => unawaited(_serve(request)));
      status = 'Chat requests enabled. Start the bundled bot on this PC.';
      notifyListeners();
    } catch (_) {
      throw const BridgeError(
        'Could not enable chat requests. Check secure storage and whether port 47653 is already in use.',
      );
    }
  }

  Future<void> _serve(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Cache-Control', 'no-store');
    try {
      if (request.headers.value('authorization') != 'Bearer $_token' ||
          request.headers.value('origin') != null) {
        request.response.statusCode = 401;
        request.response.write(
          jsonEncode({'error': 'Unauthorized bridge request.'}),
        );
        return;
      }
      if (_server == null) throw const BridgeError('Chat requests are off.');
      final path = request.uri.path;
      if (request.method != (path == '/request' ? 'POST' : 'GET')) {
        request.response.statusCode = 405;
        return;
      }
      var data = Map<String, dynamic>.from(request.uri.queryParameters);
      if (request.method == 'POST') {
        var bytes = <int>[];
        await for (final chunk in request.timeout(const Duration(seconds: 5))) {
          bytes.addAll(chunk);
          if (bytes.length > 4096)
            throw const BridgeError('Request is too large.');
        }
        data = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      }
      final result = await _handler(path, data);
      request.response.write(jsonEncode(result));
    } on BridgeError catch (error) {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({'error': error.message}));
    } catch (_) {
      request.response.statusCode = 503;
      request.response.write(
        jsonEncode({
          'error': 'SpeshTV could not complete this request. Check login, library access, and playback.',
        }),
      );
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  static final _getIt = GetIt.instance;
  static Future<void> _requests = Future.value();
  static final Map<String, Map<String, dynamic>> _receipts = {};

  static Map<String, dynamic> _item(dynamic item) {
    if (item is! AggregatedItem) return {'name': item?.toString() ?? ''};
    return {
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'year': item.productionYear,
      'series': item.seriesName,
      'season': item.parentIndexNumber,
      'episode': item.indexNumber,
    };
  }

  static bool _active(PlaybackManager manager) =>
      manager.currentResolution != null ||
      manager.bringupState.phase.isInProgress;

  Future<Map<String, dynamic>> _dispatch(
    String path,
    Map<String, dynamic> data,
  ) async {
    if (!_getIt.isRegistered<MediaServerClient>()) {
      throw const BridgeError('Sign in to your media server in SpeshTV first.');
    }
    final client = _getIt<MediaServerClient>();
    final serverId = _getIt<MediaServerClientFactory>().serverIdOf(client);
    final manager = _getIt<PlaybackManager>();
    final gate = _getIt<BlockedContentGate>();
    if (path == '/status') {
      final current = manager.queueService.currentItem;
      return {
        'active': _active(manager),
        'playing': manager.state.isPlaying,
        'current': _active(manager) && current != null ? _item(current) : null,
        'queue': manager.queueService.items
            .skip(manager.queueService.currentIndex + 1)
            .take(25)
            .map(_item)
            .toList(),
      };
    }
    if (path == '/search' || path == '/seasons' || path == '/episodes') {
      Map<String, dynamic> response;
      if (path == '/search') {
        final query = (data['query']?.toString() ?? '').trim();
        if (query.length < 2 || query.length > 100)
          throw const BridgeError('Search with 2 to 100 characters.');
        response = await client.itemsApi.getItems(
          searchTerm: query,
          includeItemTypes: ['Movie', 'Series'],
          recursive: true,
          limit: 100,
          fields: 'Type,ProductionYear,OfficialRating,SeriesName,ParentIndexNumber,IndexNumber',
        );
      } else {
        final series = data['seriesId']?.toString() ?? '';
        final parent = await client.itemsApi.getItem(series);
        if (parent['Type'] != 'Series')
          throw const BridgeError('Select a series first.');
        if (await gate.isBlocked(
          AggregatedItem(id: series, serverId: serverId, rawData: parent),
        )) {
          throw const BridgeError(
            'This series is blocked by SpeshTV settings.',
          );
        }
        response = path == '/seasons'
            ? await client.itemsApi.getSeasons(series)
            : await client.itemsApi.getEpisodes(
                series,
                seasonId: data['seasonId']?.toString(),
                fields: 'Type,SeriesName,SeriesId,OfficialRating,ParentIndexNumber,IndexNumber',
              );
      }
      final items = <Map<String, dynamic>>[];
      for (final raw in response['Items'] as List? ?? []) {
        final item = AggregatedItem(
          id: raw['Id'].toString(),
          serverId: serverId,
          rawData: Map<String, dynamic>.from(raw),
        );
        if (!gate.isBlockedNow(item)) items.add(_item(item));
      }
      return {
        'items': items,
        'truncated':
            path == '/search' &&
            (response['TotalRecordCount'] as num? ?? items.length) > 100,
      };
    }
    if (path != '/request') throw const BridgeError('Unknown bridge endpoint.');
    final receiptId = data['requestId']?.toString() ?? '';
    if (receiptId.isEmpty || receiptId.length > 100)
      throw const BridgeError('Missing request ID.');
    final done = Completer<Map<String, dynamic>>();
    _requests = _requests.catchError((_) {}).then((_) async {
      try {
        if (_receipts.containsKey(receiptId)) {
          done.complete(_receipts[receiptId]);
          return;
        }
        final id = data['itemId']?.toString() ?? '';
        final raw = await client.itemsApi.getItem(id);
        final item = AggregatedItem(id: id, serverId: serverId, rawData: raw);
        if (!{'Movie', 'Episode'}.contains(item.type))
          throw const BridgeError('Select a movie or an episode.');
        if (await gate.isBlocked(item))
          throw const BridgeError('This item is blocked by SpeshTV settings.');
        if (!enabled || !identical(_getIt<MediaServerClient>(), client)) {
          throw const BridgeError(
            'Requests were disabled or the signed-in server changed. Try again.',
          );
        }
        if (manager.queueService.items
            .skip(manager.queueService.currentIndex + 1)
            .any(
              (entry) =>
                  entry is AggregatedItem &&
                  entry.id == id &&
                  entry.serverId == serverId,
            )) {
          throw const BridgeError(
            'This item is already in the upcoming queue.',
          );
        }
        if (manager.queueService.length -
                manager.queueService.currentIndex -
                1 >=
            100)
          throw const BridgeError(
            'Queue is full. Try again after some items finish.',
          );
        final active = _active(manager);
        manager.autoAdvanceEnabled = true;
        if (active) {
          manager.queueService.addToQueue(item);
        } else {
          await _openPlayer();
          await manager.playItems([item]);
          if (manager.currentResolution == null)
            throw const BridgeError(
              'Playback did not start. Check the SpeshTV player.',
            );
        }
        final result = {
          'action': active ? 'queued' : 'playing',
          'item': _item(item),
        };
        _receipts[receiptId] = result;
        if (_receipts.length > 200) _receipts.remove(_receipts.keys.first);
        done.complete(result);
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }
}

class BridgeError implements Exception {
  final String message;
  const BridgeError(this.message);
  @override
  String toString() => message;
}
