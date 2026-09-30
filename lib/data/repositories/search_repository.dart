import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

import '../models/aggregated_item.dart';
import '../models/search_source.dart';
import '../utils/blocked_ratings.dart';

class SearchRepository {
  final MediaServerClient _client;

  static const _searchFields =
      'Type,UserData,ProductionYear,SeriesName,ParentIndexNumber,IndexNumber,'
      'AlbumArtist,Album,ImageTags,BackdropImageTags,ParentBackdropItemId,'
      'ParentBackdropImageTags,SeriesId,SeriesPrimaryImageTag,ProviderIds,OfficialRating';

  SearchRepository(this._client);

  Future<Map<String, dynamic>>? _views;
  String? _viewsUser;
  DateTime _viewsExpires = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<String, dynamic>> _userLibraries() {
    if (_viewsUser != _client.userId || DateTime.now().isAfter(_viewsExpires)) {
      _views = null;
      _viewsUser = _client.userId;
      _viewsExpires = DateTime.now().add(const Duration(minutes: 2));
    }
    final existing = _views;
    if (existing != null) return existing;
    final request = _client.userViewsApi.getUserViews();
    _views = request;
    return request.catchError((Object error) {
      if (identical(_views, request)) _views = null;
      throw error;
    });
  }

  Future<T> _retryTransient<T>(
    Future<T> Function() request, {
    required bool Function() isCurrent,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      final retryable = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          (error.type == DioExceptionType.badResponse &&
              const [408, 502, 503, 504].contains(error.response?.statusCode));
      if (!retryable || !isCurrent()) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!isCurrent()) rethrow;
      // One retry only; never retry authorization or malformed responses.
      return request();
    }
  }

  Future<List<AggregatedItem>> searchLibraries(
    String query, {
    required SearchSource source,
    required bool Function() isCurrent,
    required void Function(List<AggregatedItem>) onResults,
  }) async {
    final response = await _retryTransient(
      _userLibraries, isCurrent: isCurrent);
    if (!isCurrent()) return const [];
    final libraries = (response['Items'] as List? ?? const [])
        .whereType<Map>().where((view) {
      if (view['Id'] == null || view['CollectionType'] == 'livetv') return false;
      final vod = isVodLibrary(view['Name']?.toString() ?? '');
      return source == SearchSource.all ||
          (source == SearchSource.vod && vod) ||
          (source == SearchSource.local && !vod);
    }).toList();
    libraries.sort((a, b) =>
      (isVodLibrary(a['Name']?.toString() ?? '') ? 1 : 0).compareTo(
        isVodLibrary(b['Name']?.toString() ?? '') ? 1 : 0));
    var next = 0;
    var failures = 0;
    final results = <AggregatedItem>[];
    Future<void> worker() async {
      while (next < libraries.length && isCurrent()) {
        final library = libraries[next++];
        try {
          final items = await _retryTransient(
            () => search(query, parentId: library['Id'].toString(), limit: 48),
            isCurrent: isCurrent,
          );
          if (!isCurrent()) return;
          final label = isVodLibrary(library['Name']?.toString() ?? '') ? 'vod' : 'local';
          results.addAll(items.map((item) => AggregatedItem(
            id: item.id, serverId: item.serverId,
            rawData: {...item.rawData, 'SpeshSource': label},
          )));
          onResults(preferLocalSearchResults(results));
        } catch (_) {
          failures++;
        }
      }
    }
    await Future.wait(List.generate(libraries.length.clamp(0, 3), (_) => worker()));
    if (failures > 0 && isCurrent()) {
      throw StateError('Some libraries could not be searched. Retry the search.');
    }
    return preferLocalSearchResults(results);
  }

  Future<List<String>> suggest(
    String query, {
    String? parentId,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.toLowerCase().startsWith('studio:')) return const [];
    final normalizedQuery = trimmed.toLowerCase();

    final filter = activeParentalFilter;
    final response = await _client.itemsApi.getItems(
      searchTerm: trimmed,
      parentId: parentId,
      includeItemTypes: const ['Movie', 'Series', 'Person'],
      // Dropping blocked titles costs suggestion slots, so ask for more of
      // them when anything is blocked.
      limit: filter.isActive ? limit * 4 : limit,
      recursive: true,
      fields: 'Type,OfficialRating',
      enableTotalRecordCount: false,
      collapseBoxSetItems: false,
    );

    final items = response['Items'] as List? ?? const [];
    final seen = <String>{};
    final suggestions = <String>[];
    for (final item in items) {
      final data = item as Map<String, dynamic>;
      if (filter.isBlockedRaw(data)) continue;
      final name = (data['Name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      if (key == normalizedQuery) continue;
      if (seen.add(key)) {
        suggestions.add(name);
      }
      if (suggestions.length >= limit) break;
    }

    return suggestions;
  }

  /// People are not returned by the global `/Items` recursive query, so they
  /// need the dedicated `/Persons` endpoint. Results are tagged `Person` so the
  /// UI renders them as circular avatars and groups them correctly.
  Future<List<AggregatedItem>> searchPeople(
    String query, {
    int limit = 24,
    bool Function()? isCurrent,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('studio:')) {
      return const [];
    }

    final response = await _retryTransient(() => _client.itemsApi.getPersons(
      searchTerm: trimmed,
      limit: limit,
      fields: 'PrimaryImageAspectRatio',
      enableImageTypes: 'Primary',
    ), isCurrent: isCurrent ?? () => true);

    final items = response['Items'] as List? ?? const [];
    return items.map((item) {
      final data = Map<String, dynamic>.from(item as Map);
      data['Type'] ??= 'Person';
      return AggregatedItem(
        id: data['Id']?.toString() ?? '',
        serverId: data['ServerId']?.toString() ?? '',
        rawData: data,
      );
    }).toList();
  }

  /// Live TV channels never come back from the recursive items search, so
  /// channel search fetches the lineup and filters by name client-side.
  Future<List<AggregatedItem>> fetchLiveTvChannels() async {
    final response = await _client.liveTvApi.getChannels(
      fields: 'ImageTags,ChannelNumber,CurrentProgram',
      enableTotalRecordCount: false,
      userId: _client.userId,
    );
    final items = response['Items'] as List? ?? const [];
    return items.map((item) {
      final data = Map<String, dynamic>.from(item as Map);
      data['Type'] ??= 'TvChannel';
      return AggregatedItem(
        id: data['Id']?.toString() ?? '',
        serverId: data['ServerId']?.toString() ?? '',
        rawData: data,
      );
    }).toList();
  }

  Future<List<AggregatedItem>> search(
    String query, {
    List<String>? includeItemTypes,
    String? parentId,
    int? limit,
  }) async {
    final isStudioQuery = query.toLowerCase().startsWith('studio:');
    final searchTerm = isStudioQuery ? null : query;
    final studios = isStudioQuery ? [query.substring('studio:'.length)] : null;

    final response = await _client.itemsApi.getItems(
      searchTerm: searchTerm,
      parentId: parentId,
      includeItemTypes: includeItemTypes,
      limit: limit ?? 24,
      recursive: true,
      fields: _searchFields,
      studios: studios,
      enableTotalRecordCount: false,
      collapseBoxSetItems: false,
    );

    final items = response['Items'] as List? ?? [];
    return withoutBlockedItems(
      items.map((item) {
        final data = item as Map<String, dynamic>;
        return AggregatedItem(
          id: data['Id']?.toString() ?? '',
          serverId: data['ServerId']?.toString() ?? '',
          rawData: data,
        );
      }).toList(),
    );
  }
}
