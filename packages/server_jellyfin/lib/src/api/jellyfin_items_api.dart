import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class JellyfinItemsApi implements ItemsApi {
  final Dio _dio;
  final String Function() _getUserId;
  final _genreCache = <String, ({DateTime saved, Map<String, dynamic> data})>{};
  final _pendingGenres = <String, Future<Map<String, dynamic>>>{};

  JellyfinItemsApi(this._dio, this._getUserId);

  Future<Response<dynamic>> _getProgress(
    String path,
    Map<String, dynamic> queryParameters,
  ) async {
    if ((!const bool.fromEnvironment('SPESHTV_WEB') &&
            !const bool.fromEnvironment('SPESHMEDIA_CLIENT')) ||
        queryParameters['MediaTypes'] == 'Audio') {
      return _dio.get(path, queryParameters: queryParameters);
    }
    // Match the lightweight SpeshTV feed, not the full catalog-detail DTO.
    // Counting every resumable item is particularly costly on large libraries.
    final lean = <String, dynamic>{
      ...queryParameters,
      'UserId': _getUserId(),
      'Fields': 'ProviderIds,ProductionYear,PrimaryImageAspectRatio',
      'EnableUserData': true,
      'EnableTotalRecordCount': false,
      if (path == '/UserItems/Resume') 'MediaTypes': 'Video',
      if (path == '/Shows/NextUp') 'EnableRewatching': false,
    }..remove('EnableImageTypes');
    final route = path == '/UserItems/Resume'
        ? '/Users/${Uri.encodeComponent(_getUserId())}/Items/Resume'
        : path;
    final options = Options(method: 'GET')
        .compose(_dio.options, route, queryParameters: lean)
        .copyWith(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );
    final response = await _dio.fetch<dynamic>(options);
    // No-count responses can report only this page's length, not the total.
    // Let the progress feed detect the end from a short page instead.
    if (response.data is Map<String, dynamic>) {
      response.data = <String, dynamic>{
        ...response.data as Map<String, dynamic>,
        'TotalRecordCount': 0,
      };
    }
    return response;
  }

  Future<Response<dynamic>> _getSearch(
    String path,
    Map<String, dynamic> queryParameters, {
    Duration? receiveTimeout,
  }) {
    // Browser connection timeout includes waiting for response headers and
    // a connection slot. Large catalog searches need more than eight seconds.
    final options = Options(method: 'GET')
        .compose(_dio.options, path, queryParameters: queryParameters)
        .copyWith(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: receiveTimeout ?? _dio.options.receiveTimeout,
        );
    return _dio.fetch<dynamic>(options);
  }

  bool _shouldRetryCollectionFallback(int statusCode) {
    return statusCode == 400 ||
        statusCode == 404 ||
        statusCode == 405 ||
        statusCode == 415 ||
        statusCode == 422;
  }

  @override
  Future<Map<String, dynamic>> getItems({
    bool? serverWide,
    String? parentId,
    List<String>? ids,
    List<String>? includeItemTypes,
    List<String>? excludeItemTypes,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? searchTerm,
    String? fields,
    List<String>? personIds,
    List<String>? artistIds,
    List<String>? filters,
    List<String>? seriesStatus,
    String? nameStartsWith,
    String? nameLessThan,
    List<String>? genreIds,
    List<String>? genres,
    bool? isFavorite,
    bool? collapseBoxSetItems,
    bool? enableTotalRecordCount,
    String? enableImageTypes,
    int? imageTypeLimit,
    List<String>? tags,
    List<String>? studios,
    DateTime? minPremiereDate,
    String? maxOfficialRating,
    bool? hasParentalRating,
    String? anyProviderIdEquals,
    List<String>? officialRatings,
    List<int>? years,
    List<String>? videoTypes,
    List<String>? audioLanguages,
    List<String>? subtitleLanguages,
    bool? hasSubtitles,
    bool? hasTrailer,
    bool? hasSpecialFeature,
    bool? hasThemeSong,
    bool? hasThemeVideo,
    bool? isHd,
    bool? is4K,
    bool? is3D,
  }) async {
    final queryParams = {
      'ParentId': ?parentId,
      if (ids != null) 'Ids': ids.join(','),
      if (includeItemTypes != null)
        'IncludeItemTypes': includeItemTypes.join(','),
      if (excludeItemTypes != null)
        'ExcludeItemTypes': excludeItemTypes.join(','),
      'SortBy': ?sortBy,
      'SortOrder': ?sortOrder,
      'StartIndex': ?startIndex,
      'Limit': ?limit,
      'Recursive': ?recursive,
      'SearchTerm': ?searchTerm,
      'Fields': ?fields,
      if (personIds != null) 'PersonIds': personIds.join(','),
      if (artistIds != null) 'ArtistIds': artistIds.join(','),
      if (filters != null) 'Filters': filters.join(','),
      if (seriesStatus != null) 'SeriesStatus': seriesStatus.join(','),
      'NameStartsWith': ?nameStartsWith,
      'NameLessThan': ?nameLessThan,
      if (genreIds != null) 'GenreIds': genreIds.join(','),
      // Genres, ratings and tags are pipe delimited so a value holding a comma
      // still arrives whole.
      if (genres != null && genres.isNotEmpty) 'Genres': genres.join('|'),
      if (officialRatings != null && officialRatings.isNotEmpty)
        'OfficialRatings': officialRatings.join('|'),
      if (years != null && years.isNotEmpty) 'Years': years.join(','),
      if (videoTypes != null && videoTypes.isNotEmpty)
        'VideoTypes': videoTypes.join(','),
      if (audioLanguages != null && audioLanguages.isNotEmpty)
        'AudioLanguages': audioLanguages.join(','),
      if (subtitleLanguages != null && subtitleLanguages.isNotEmpty)
        'SubtitleLanguages': subtitleLanguages.join(','),
      'HasSubtitles': ?hasSubtitles,
      'HasTrailer': ?hasTrailer,
      'HasSpecialFeature': ?hasSpecialFeature,
      'HasThemeSong': ?hasThemeSong,
      'HasThemeVideo': ?hasThemeVideo,
      'IsHd': ?isHd,
      'Is4K': ?is4K,
      'Is3D': ?is3D,
      'IsFavorite': ?isFavorite,
      'CollapseBoxSetItems': ?collapseBoxSetItems,
      'EnableTotalRecordCount': ?enableTotalRecordCount,
      'EnableImageTypes': ?enableImageTypes,
      'ImageTypeLimit': ?imageTypeLimit,
      if (tags != null && tags.isNotEmpty) 'Tags': tags.join('|'),
      if (studios != null && studios.isNotEmpty) 'Studios': studios.join('|'),
      if (minPremiereDate != null)
        'MinPremiereDate': minPremiereDate.toUtc().toIso8601String(),
      'MaxOfficialRating': ?maxOfficialRating,
      'HasParentalRating': ?hasParentalRating,
      'AnyProviderIdEquals': ?anyProviderIdEquals,
    };
    final String path;
    if (serverWide == true) {
      path = '/Items';
    } else {
      final userId = _getUserId();
      path = '/Users/$userId/Items';
    }
    final response = searchTerm?.trim().isNotEmpty == true
        ? await _getSearch(path, queryParams)
        : await _dio.get(path, queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<QueryFilterValues> getQueryFilters({
    String? parentId,
    List<String>? includeItemTypes,
  }) => readQueryFilters(
    _dio,
    userId: _getUserId(),
    parentId: parentId,
    includeItemTypes: includeItemTypes,
  );

  @override
  Future<Map<String, dynamic>> getPersons({
    required String searchTerm,
    int? limit,
    String? fields,
    String? enableImageTypes,
  }) async {
    final response = await _getSearch('/Persons', {
      'UserId': _getUserId(),
      'SearchTerm': searchTerm,
      'Limit': ?limit,
      'Fields': ?fields,
      'EnableImageTypes': ?enableImageTypes,
      'EnableTotalRecordCount': false,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getItem(
    String itemId, {
    String? mediaSourceId,
    String? fields,
  }) async {
    final userId = _getUserId();
    final response = await _dio.get(
      '/Users/$userId/Items/$itemId',
      queryParameters: {
        'Fields': fields ?? kDetailItemFields,
        if (mediaSourceId != null) 'mediaSourceId': mediaSourceId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getAncestors(String itemId) async {
    final response = await _dio.get('/Items/$itemId/Ancestors');
    return ((response.data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> getSimilarItems(
    String itemId, {
    int? limit,
    String? bypass,
  }) async {
    final params = <String, dynamic>{'Limit': ?limit, 'bypass': ?bypass};
    final response = await _dio.get(
      '/Items/$itemId/Similar',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getNextUp({
    String? seriesId,
    String? parentId,
    int? startIndex,
    int? limit,
    String? fields,
    bool? enableResumable,
    DateTime? nextUpDateCutoff,
    String? enableImageTypes,
    int? imageTypeLimit,
  }) async {
    final userId = _getUserId();
    final response = await _getProgress('/Shows/NextUp', {
      'UserId': userId,
      'SeriesId': ?seriesId,
      'ParentId': ?parentId,
      'StartIndex': ?startIndex,
      'Limit': ?limit,
      'Fields': ?fields,
      'EnableResumable': ?enableResumable,
      'NextUpDateCutoff': ?nextUpDateCutoff?.toUtc().toIso8601String(),
      'EnableImageTypes': ?enableImageTypes,
      'ImageTypeLimit': ?imageTypeLimit,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getResumeItems({
    String? parentId,
    List<String>? includeItemTypes,
    String? mediaTypes,
    int? startIndex,
    int? limit,
    String? fields,
    String? enableImageTypes,
    int? imageTypeLimit,
  }) async {
    final response = await _getProgress('/UserItems/Resume', {
      'ParentId': ?parentId,
      if (includeItemTypes != null)
        'IncludeItemTypes': includeItemTypes.join(','),
      if (mediaTypes != null) 'MediaTypes': mediaTypes,
      'StartIndex': ?startIndex,
      'Limit': ?limit,
      'Fields': ?fields,
      'EnableImageTypes': ?enableImageTypes,
      'ImageTypeLimit': ?imageTypeLimit,
    });
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getLatestItems({
    String? parentId,
    List<String>? includeItemTypes,
    int? limit,
    String? fields,
    String? enableImageTypes,
    int? imageTypeLimit,
  }) async {
    final userId = _getUserId();
    final path = userId.isNotEmpty
        ? '/Users/$userId/Items/Latest'
        : '/Items/Latest';
    final response = await _dio.get(
      path,
      queryParameters: {
        'ParentId': ?parentId,
        if (includeItemTypes != null)
          'IncludeItemTypes': includeItemTypes.join(','),
        'Limit': ?limit,
        'Fields': ?fields,
        'EnableImageTypes': ?enableImageTypes,
        'ImageTypeLimit': ?imageTypeLimit,
      },
    );
    final data = response.data;
    if (data is List) return {'Items': data, 'TotalRecordCount': data.length};
    return data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getRecentlyReleasedItems({
    String? parentId,
    List<String>? includeItemTypes,
    int? limit,
    String? fields,
    String? enableImageTypes,
    int? imageTypeLimit,
    bool recursive = false,
  }) async {
    final userId = _getUserId();
    final response = await _dio.get(
      '/Users/$userId/Items',
      queryParameters: {
        'ParentId': ?parentId,
        if (recursive) 'Recursive': true,
        if (includeItemTypes != null)
          'IncludeItemTypes': includeItemTypes.join(','),
        'Limit': ?limit,
        'Fields': ?fields,
        'EnableImageTypes': ?enableImageTypes,
        'ImageTypeLimit': ?imageTypeLimit,
        'SortBy': 'PremiereDate',
        'SortOrder': 'Descending',
        'MaxPremiereDate': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final data = response.data;
    if (data is List) return {'Items': data, 'TotalRecordCount': data.length};
    return data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getSeasons(
    String seriesId, {
    String? fields,
  }) async {
    final response = await _dio.get(
      '/Shows/$seriesId/Seasons',
      queryParameters: {'Fields': ?fields, 'UserId': _getUserId()},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getEpisodes(
    String seriesId, {
    String? seasonId,
    String? fields,
  }) async {
    final response = await _dio.get(
      '/Shows/$seriesId/Episodes',
      queryParameters: {
        'UserId': _getUserId(),
        'SeasonId': ?seasonId,
        'Fields': ?fields,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getThemeMedia(
    String itemId, {
    bool inheritFromParent = true,
  }) async {
    // Discovery IDs belong to TMDB, not the Jellyfin item database.
    if (itemId.startsWith('tmdb:')) {
      return <String, dynamic>{
        'ThemeSongsResult': <String, dynamic>{'Items': <dynamic>[]},
        'ThemeVideosResult': <String, dynamic>{'Items': <dynamic>[]},
      };
    }
    final response = await _dio.get(
      '/Items/$itemId/ThemeMedia',
      queryParameters: {'InheritFromParent': inheritFromParent},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getPlaylists() async {
    final userId = _getUserId();
    final response = await _dio.get(
      '/Users/$userId/Items',
      queryParameters: {
        'IncludeItemTypes': 'Playlist',
        'Recursive': true,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getArtists({
    String? parentId,
    String? userId,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? fields,
    String? nameStartsWith,
    String? nameLessThan,
    bool? isFavorite,
  }) async {
    final response = await _dio.get(
      '/Artists',
      queryParameters: {
        'ParentId': ?parentId,
        'UserId': ?userId,
        'SortBy': ?sortBy,
        'SortOrder': ?sortOrder,
        'StartIndex': ?startIndex,
        'Limit': ?limit,
        'Recursive': ?recursive,
        'Fields': ?fields,
        'NameStartsWith': ?nameStartsWith,
        'NameLessThan': ?nameLessThan,
        'IsFavorite': ?isFavorite,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getAlbumArtists({
    String? parentId,
    String? userId,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? fields,
    String? nameStartsWith,
    String? nameLessThan,
    bool? isFavorite,
  }) async {
    final response = await _dio.get(
      '/Artists/AlbumArtists',
      queryParameters: {
        'ParentId': ?parentId,
        'UserId': ?userId,
        'SortBy': ?sortBy,
        'SortOrder': ?sortOrder,
        'StartIndex': ?startIndex,
        'Limit': ?limit,
        'Recursive': ?recursive,
        'Fields': ?fields,
        'NameStartsWith': ?nameStartsWith,
        'NameLessThan': ?nameLessThan,
        'IsFavorite': ?isFavorite,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getPlaylistItems(
    String playlistId, {
    int? startIndex,
    int? limit,
  }) async {
    final response = await _dio.get(
      '/Playlists/$playlistId/Items',
      queryParameters: {
        'Fields':
            'BasicSyncInfo,PrimaryImageAspectRatio,RunTimeTicks,Artists,AlbumArtist,IndexNumber,MediaType,PlaylistItemId,BackdropImageTags,ParentBackdropImageTags,ParentBackdropItemId,SeriesName,ParentIndexNumber,Genres,Chapters,Overview,UserData,MediaStreams,DateCreated,SortName',
        'EnableImageTypes': 'Primary,Backdrop,Logo,Thumb',
        'ImageTypeLimit': 1,
        'StartIndex': ?startIndex,
        'Limit': ?limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Jellyfin makes a new playlist public unless told otherwise.
  @override
  Future<Map<String, dynamic>> createPlaylist({
    required String name,
    List<String>? itemIds,
  }) async {
    final response = await _dio.post(
      '/Playlists',
      data: {'Name': name, 'Ids': ?itemIds, 'IsPublic': false},
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createCollection({
    required String name,
    List<String>? itemIds,
  }) async {
    final hasItems = itemIds != null && itemIds.isNotEmpty;
    final ids = hasItems ? itemIds.join(',') : null;
    final queryParameters = <String, dynamic>{
      'name': name,
      'Name': name,
      if (ids != null) 'ids': ids,
      if (ids != null) 'Ids': ids,
    };

    Response<dynamic> response;
    try {
      response = await _dio.post(
        '/Collections',
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (!_shouldRetryCollectionFallback(statusCode)) {
        rethrow;
      }

      response = await _dio.post(
        '/Collections',
        queryParameters: queryParameters,
        data: {'Name': name, if (hasItems) 'Ids': itemIds},
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  @override
  Future<void> addToPlaylist(String playlistId, List<String> itemIds) async {
    await _dio.post(
      '/Playlists/$playlistId/Items',
      queryParameters: {'Ids': itemIds.join(',')},
    );
  }

  @override
  Future<void> addToCollection(
    String collectionId,
    List<String> itemIds,
  ) async {
    final ids = itemIds.join(',');
    final path = '/Collections/$collectionId/Items';

    Future<void> send({String? queryKey, bool includeBody = false}) async {
      await _dio.post(
        path,
        queryParameters: queryKey == null ? null : {queryKey: ids},
        data: includeBody ? {'Ids': itemIds, 'ids': ids} : null,
      );
    }

    for (final queryKey in const ['Ids', 'ids']) {
      try {
        await send(queryKey: queryKey);
        return;
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode ?? 0;
        if (!_shouldRetryCollectionFallback(statusCode)) {
          rethrow;
        }
      }
    }

    await send(includeBody: true);
  }

  @override
  Future<void> removeFromCollection(
    String collectionId,
    List<String> itemIds,
  ) async {
    await _dio.delete(
      '/Collections/$collectionId/Items',
      queryParameters: {'Ids': itemIds.join(',')},
    );
  }

  @override
  Future<void> removeFromPlaylist(
    String playlistId,
    List<String> entryIds,
  ) async {
    await _dio.delete(
      '/Playlists/$playlistId/Items',
      queryParameters: {'EntryIds': entryIds.join(',')},
    );
  }

  @override
  Future<void> movePlaylistItem(
    String playlistId,
    String playlistItemId,
    int newIndex,
  ) async {
    await _dio.post(
      '/Playlists/$playlistId/Items/$playlistItemId/Move/$newIndex',
    );
  }

  @override
  Future<void> renamePlaylist(String playlistId, String name) async {
    await _dio.post('/Playlists/$playlistId', data: {'Name': name});
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _dio.delete('/Items/$itemId');
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await deleteItem(playlistId);
  }

  @override
  Future<Map<String, dynamic>> getGenres({
    String? parentId,
    String? userId,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? fields,
    List<String>? includeItemTypes,
  }) async {
    final query = <String, dynamic>{
      'ParentId': ?parentId,
      // Defaulted rather than left to callers. Without a user the server
      // answers across every library, including ones this account can't see.
      'UserId': userId ?? _getUserId(),
      'SortBy': ?sortBy,
      'SortOrder': ?sortOrder,
      'StartIndex': ?startIndex,
      'Limit': ?limit,
      'Recursive': ?recursive,
      'Fields': ?fields,
      if (includeItemTypes != null && includeItemTypes.isNotEmpty)
        'IncludeItemTypes': includeItemTypes.join(','),
    };
    final cacheKey = jsonEncode(query);
    final cached = _genreCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.saved) < const Duration(minutes: 2)) {
      return cached.data;
    }
    Future<Map<String, dynamic>> fetch() async {
      // A large filtered catalogue can take 35-40 seconds even without counts.
      final response = await _getSearch(
        '/Genres',
        query,
        receiveTimeout: const Duration(seconds: 60),
      );
      final data = response.data as Map<String, dynamic>;
      _genreCache.remove(cacheKey);
      _genreCache[cacheKey] = (saved: DateTime.now(), data: data);
      while (_genreCache.length > 8) {
        _genreCache.remove(_genreCache.keys.first);
      }
      return data;
    }

    return _pendingGenres[cacheKey] ??= fetch().whenComplete(() {
      _pendingGenres.remove(cacheKey);
    });
  }

  @override
  Future<Map<String, dynamic>> getStudios({
    String? parentId,
    String? userId,
    String? sortBy,
    String? sortOrder,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? fields,
    List<String>? includeItemTypes,
  }) async {
    final response = await _dio.get(
      '/Studios',
      queryParameters: {
        'ParentId': ?parentId,
        'UserId': ?userId,
        'SortBy': ?sortBy,
        'SortOrder': ?sortOrder,
        'StartIndex': ?startIndex,
        'Limit': ?limit,
        'Recursive': ?recursive,
        'Fields': ?fields,
        if (includeItemTypes != null && includeItemTypes.isNotEmpty)
          'IncludeItemTypes': includeItemTypes.join(','),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getLyrics(String itemId) async {
    final response = await _dio.get('/Audio/$itemId/Lyrics');
    return response.data as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _parseItemListResponse(dynamic data) {
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map<String, dynamic>) {
      final items = data['Items'] as List?;
      if (items == null) return const [];
      return items
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalTrailers(String itemId) async {
    final userId = _getUserId();
    final response = await _dio.get(
      '/Users/$userId/Items/$itemId/LocalTrailers',
    );
    return _parseItemListResponse(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getIntros(String itemId) async {
    final userId = _getUserId();
    final response = await _dio.get('/Users/$userId/Items/$itemId/Intros');
    return _parseItemListResponse(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getSpecialFeatures(String itemId) async {
    final response = await _dio.get('/Items/$itemId/SpecialFeatures');
    final data = response.data;
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAdditionalParts(String itemId) async {
    final response = await _dio.get(
      '/Videos/$itemId/AdditionalParts',
      queryParameters: {'UserId': _getUserId()},
    );
    return _parseItemListResponse(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getMediaSegments(String itemId) async {
    final response = await _dio.get('/MediaSegments/$itemId');
    final data = response.data as Map<String, dynamic>;
    final items = data['Items'] as List? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> searchRemoteSubtitles(
    String itemId, {
    required String language,
    bool? isPerfectMatch,
  }) async {
    final response = await _dio.get(
      '/Items/$itemId/RemoteSearch/Subtitles/$language',
      queryParameters: {'IsPerfectMatch': ?isPerfectMatch},
    );
    return ((response.data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<void> downloadRemoteSubtitle(String itemId, String subtitleId) async {
    await _dio.post('/Items/$itemId/RemoteSearch/Subtitles/$subtitleId');
  }
}
