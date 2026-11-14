import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/viewmodels/library_browse_view_model.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the last page request asked the server for, which is the only
/// thing these tests care about.
class _RecordingItemsApi implements ItemsApi {
  List<String>? filters;
  List<String>? seriesStatus;
  List<String>? genres;
  List<String>? officialRatings;
  List<String>? tags;
  List<int>? years;
  List<String>? videoTypes;
  List<String>? audioLanguages;
  List<String>? subtitleLanguages;
  bool? hasSubtitles;
  bool? hasTrailer;
  bool? hasSpecialFeature;
  bool? isHd;
  bool? is4K;
  bool? is3D;
  List<String>? includeItemTypes;
  List<String>? excludeItemTypes;
  List<String>? genreIds;
  bool? collapseBoxSetItems;
  String? collectionType;

  QueryFilterValues facets = QueryFilterValues.empty;
  int facetRequests = 0;
  final List<int> offsets = [];
  List<Map<String, dynamic>>? pageResponses;
  @override
  Future<List<Map<String, dynamic>>> getAncestors(String itemId) async => [
    {'Id': itemId.startsWith('local') ? 'local-library' : 'vod-library'},
  ];

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
    this.filters = filters;
    this.seriesStatus = seriesStatus;
    this.genres = genres;
    this.officialRatings = officialRatings;
    this.tags = tags;
    this.years = years;
    this.videoTypes = videoTypes;
    this.audioLanguages = audioLanguages;
    this.subtitleLanguages = subtitleLanguages;
    this.hasSubtitles = hasSubtitles;
    this.hasTrailer = hasTrailer;
    this.hasSpecialFeature = hasSpecialFeature;
    this.isHd = isHd;
    this.is4K = is4K;
    this.is3D = is3D;
    this.includeItemTypes = includeItemTypes;
    this.excludeItemTypes = excludeItemTypes;
    this.genreIds = genreIds;
    this.collapseBoxSetItems = collapseBoxSetItems;
    offsets.add(startIndex ?? 0);
    if (pageResponses != null && pageResponses!.isNotEmpty) {
      return pageResponses!.removeAt(0);
    }
    return <String, dynamic>{'TotalRecordCount': 0, 'Items': const []};
  }

  @override
  Future<QueryFilterValues> getQueryFilters({
    String? parentId,
    List<String>? includeItemTypes,
  }) async {
    facetRequests++;
    return facets;
  }

  @override
  Future<Map<String, dynamic>> getItem(
    String itemId, {
    String? mediaSourceId,
    String? fields,
  }) async => <String, dynamic>{
    'Name': 'Media',
    'CollectionType': collectionType ?? 'movies',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClient implements MediaServerClient {
  _FakeClient(this.itemsApi, {this.serverType = ServerType.jellyfin,
    this.baseUrl = 'http://server', this.userId = 'user'});

  @override
  final ItemsApi itemsApi;

  @override
  final ServerType serverType;

  @override
  final String baseUrl;

  @override
  final String? userId;

  @override
  UserViewsApi get userViewsApi => _BrowseViews();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrowseViews implements UserViewsApi {
  @override
  Future<Map<String, dynamic>> getUserViews({bool includeHidden = false}) async => {
    'Items': [
      {'Id': 'local-library', 'Name': 'Movies', 'CollectionType': 'movies'},
      {'Id': 'vod-library', 'Name': 'VOD FHD Movies', 'CollectionType': 'movies'},
    ],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMdbListRepository implements MdbListRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<LibraryBrowseViewModel> _viewModel(
  _RecordingItemsApi api, {
  ServerType serverType = ServerType.jellyfin,
  String libraryId = 'movies',
  String? genreId,
  List<String>? includeItemTypes,
  bool groupCollections = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = PreferenceStore();
  await store.init();
  final prefs = UserPreferences(store);
  if (groupCollections) {
    prefs.set(UserPreferences.groupItemsIntoCollections, true);
  }
  return LibraryBrowseViewModel(
    libraryId: libraryId,
    client: _FakeClient(api, serverType: serverType),
    prefs: prefs,
    mdbListRepository: _FakeMdbListRepository(),
    genreId: genreId,
    includeItemTypes: includeItemTypes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('combined pages prefer local and finish at the raw server total', () async {
    Map<String, dynamic> page(String id) => {
      'TotalRecordCount': 2,
      'Items': [{'Id': id, 'Name': 'Title', 'Type': 'Movie',
        'ProductionYear': 2020, 'ProviderIds': {'Tmdb': '10'}}],
    };
    final api = _RecordingItemsApi()..pageResponses = [page('vod'), page('local')];
    final vm = await _viewModel(api, libraryId: '', includeItemTypes: ['Movie']);
    addTearDown(vm.dispose);
    await vm.setPlayedFilter(PlayedStatusFilter.unwatched);
    await vm.loadMore();
    expect(vm.items.map((item) => item.id), ['local']);
    expect(vm.hasMore, isFalse);
    expect(api.offsets, [0, 1]);
  });

  test('a specific library preserves all editions', () async {
    final api = _RecordingItemsApi()..pageResponses = [{
      'TotalRecordCount': 2,
      'Items': [for (final id in ['vod', 'local'])
        {'Id': id, 'Name': 'Title', 'Type': 'Movie',
          'ProductionYear': 2020, 'ProviderIds': {'Tmdb': '10'}}],
    }];
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);
    await vm.setPlayedFilter(PlayedStatusFilter.unwatched);
    expect(vm.items.length, 2);
  });

  test('infinite browsing backfills duplicates using raw server offsets', () async {
    Map<String, dynamic> page(String id) => {
      'TotalRecordCount': 20,
      'Items': [{'Id': id, 'Name': id, 'Type': 'Movie'}],
    };
    final api = _RecordingItemsApi()
      ..pageResponses = [page('first'), page('first'), page('second')];
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);
    await vm.setPlayedFilter(PlayedStatusFilter.unwatched);
    await vm.loadMore();
    expect(vm.items.map((item) => item.id), ['first', 'second']);
    expect(api.offsets, [0, 1, 2]);
    expect(vm.loadingMore, isFalse);
  });

  test('duplicate backfill is bounded and an empty page ends paging', () async {
    final duplicate = <String, dynamic>{
      'TotalRecordCount': 100,
      'Items': [{'Id': 'first', 'Name': 'First', 'Type': 'Movie'}],
    };
    final api = _RecordingItemsApi()
      ..pageResponses = List.generate(7, (_) => duplicate);
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);
    await vm.setPlayedFilter(PlayedStatusFilter.unwatched);
    await vm.loadMore();
    expect(api.offsets.length, 6);
    expect(vm.hasMore, isTrue);
    api.pageResponses = [{'TotalRecordCount': 100, 'Items': []}];
    await vm.loadMore();
    expect(vm.hasMore, isFalse);
  });

  test('library sort and filters survive reopening the view', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);
    LibraryBrowseViewModel open({String user = 'user', String server = 'http://server'}) => LibraryBrowseViewModel(
      libraryId: 'movies', client: _FakeClient(_RecordingItemsApi(), userId: user, baseUrl: server),
      prefs: prefs, mdbListRepository: _FakeMdbListRepository(),
    );
    final first = open();
    await first.setSortBy(LibrarySortBy.dateAdded);
    await first.setPlayedFilter(PlayedStatusFilter.unwatched);
    first.dispose();
    final reopened = open();
    addTearDown(reopened.dispose);
    expect(reopened.sortBy, LibrarySortBy.dateAdded);
    expect(reopened.playedFilter, PlayedStatusFilter.unwatched);
    if (const bool.fromEnvironment('SPESHTV_WEB')) {
      final otherMember = open(user: 'other');
      final otherServer = open(server: 'http://other');
      addTearDown(otherMember.dispose);
      addTearDown(otherServer.dispose);
      expect(otherMember.playedFilter, PlayedStatusFilter.all);
      expect(otherServer.playedFilter, PlayedStatusFilter.all);
    }
  });

  test('in progress asks for the resumable items', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.setPlayedFilter(PlayedStatusFilter.inProgress);

    expect(api.filters, contains('IsResumable'));
  });

  test('unreleased reaches the series status', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.setSeriesFilter(SeriesStatusFilter.unreleased);

    expect(api.seriesStatus, <String>['Unreleased']);
  });

  test('each feature travels as its own flag', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.toggleFeatureFilter(LibraryFeatureFilter.subtitles);
    await vm.toggleFeatureFilter(LibraryFeatureFilter.extras);

    expect(api.hasSubtitles, isTrue);
    expect(api.hasSpecialFeature, isTrue);
    // Nothing was asked of the features left alone.
    expect(api.hasTrailer, isNull);
  });

  test('asking for both SD and HD asks for neither', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.toggleVideoQualityFilter(LibraryVideoQualityFilter.hd);
    expect(api.isHd, isTrue);

    await vm.toggleVideoQualityFilter(LibraryVideoQualityFilter.sd);
    expect(api.isHd, isNull);

    await vm.toggleVideoQualityFilter(LibraryVideoQualityFilter.uhd);
    expect(api.is4K, isTrue);
    expect(api.is3D, isNull);
  });

  test('disc sources travel as the server video types', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.toggleVideoSourceFilter(LibraryVideoSourceFilter.bluray);

    expect(api.videoTypes, <String>['BluRay']);
  });

  test('facet choices reach the query as the values they came from', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.toggleGenreFilter('Drama');
    await vm.toggleOfficialRatingFilter('PG-13');
    await vm.toggleTagFilter('4k-remux');
    await vm.toggleYearFilter('1999');
    await vm.toggleAudioLanguageFilter('jpn');
    await vm.toggleSubtitleLanguageFilter('eng');

    expect(api.genres, <String>['Drama']);
    expect(api.officialRatings, <String>['PG-13']);
    expect(api.tags, <String>['4k-remux']);
    expect(api.years, <int>[1999]);
    expect(api.audioLanguages, <String>['jpn']);
    expect(api.subtitleLanguages, <String>['eng']);
  });

  test('clearing puts every filter back', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.setPlayedFilter(PlayedStatusFilter.watched);
    await vm.toggleFeatureFilter(LibraryFeatureFilter.subtitles);
    await vm.toggleTagFilter('imax');
    expect(vm.hasActiveFilters, isTrue);
    expect(vm.activeFilterCount, 3);
    final sort = vm.sortBy;

    await vm.clearFilters();

    expect(vm.hasActiveFilters, isFalse);
    expect(vm.activeFilterCount, 0);
    expect(vm.sortBy, sort);
    expect(api.filters, isNull);
    expect(api.hasSubtitles, isNull);
    expect(api.tags, isNull);
  });

  test('clearing one group leaves the others in place', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.toggleGenreFilter('Horror');
    await vm.toggleTagFilter('imax');
    await vm.toggleVideoQualityFilter(LibraryVideoQualityFilter.hd);
    await vm.toggleFeatureFilter(LibraryFeatureFilter.subtitles);

    await vm.clearFilterGroup(LibraryFilterGroup.genres);
    await vm.clearFilterGroup(LibraryFilterGroup.quality);

    expect(vm.genreFilters, isEmpty);
    expect(api.genres, isNull);
    expect(api.isHd, isNull);
    expect(api.tags, <String>['imax']);
    expect(api.hasSubtitles, isTrue);
  });

  test('the facet values are only read once per browse', () async {
    final api = _RecordingItemsApi()
      ..facets = const QueryFilterValues(
        officialRatings: ['PG'],
        years: [1999],
      );
    final vm = await _viewModel(api);
    addTearDown(vm.dispose);

    await vm.ensureFacetValuesLoaded();
    await vm.ensureFacetValuesLoaded();

    expect(api.facetRequests, 1);
    expect(vm.facetValues.years, <int>[1999]);
  });

  test('Emby hides the two options its items query has no answer for', () async {
    final jellyfin = await _viewModel(_RecordingItemsApi());
    addTearDown(jellyfin.dispose);
    expect(jellyfin.supportsUhdFilter, isTrue);
    expect(jellyfin.supportsUnreleasedSeriesFilter, isTrue);

    final emby = await _viewModel(
      _RecordingItemsApi(),
      serverType: ServerType.emby,
    );
    addTearDown(emby.dispose);
    expect(emby.supportsUhdFilter, isFalse);
    expect(emby.supportsUnreleasedSeriesFilter, isFalse);
  });

  test('global genre browse includes only movies and series and excludes non-root types', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(
      api,
      libraryId: '',
      genreId: 'anime-genre-id',
    );
    addTearDown(vm.dispose);

    await vm.load();

    expect(api.genreIds, ['anime-genre-id']);
    expect(api.includeItemTypes, ['Movie', 'Series']);
    expect(api.excludeItemTypes, ['Playlist', 'Episode', 'Season', 'Folder']);
    expect(api.collapseBoxSetItems, isFalse);
  });

  test('global genre browse with groupCollections includes BoxSet and sets collapseBoxSetItems', () async {
    final api = _RecordingItemsApi();
    final vm = await _viewModel(
      api,
      libraryId: '',
      genreId: 'anime-genre-id',
      groupCollections: true,
    );
    addTearDown(vm.dispose);

    await vm.load();

    expect(api.genreIds, ['anime-genre-id']);
    expect(api.includeItemTypes, ['Movie', 'Series', 'BoxSet']);
    expect(api.excludeItemTypes, ['Playlist', 'Episode', 'Season', 'Folder']);
    expect(api.collapseBoxSetItems, isTrue);
  });

  test('genre browse in music library asks for MusicAlbum', () async {
    final api = _RecordingItemsApi()..collectionType = 'music';
    final vm = await _viewModel(
      api,
      libraryId: 'music-library-id',
      genreId: 'rock-genre-id',
    );
    addTearDown(vm.dispose);

    await vm.load();

    expect(api.genreIds, ['rock-genre-id']);
    expect(api.includeItemTypes, ['MusicAlbum']);
    expect(api.excludeItemTypes, ['Playlist', 'Episode', 'Season', 'Folder']);
  });

  // A book library already picked its own types, so narrowing a genre to
  // movies and series there leaves the page with nothing to show.
  test('genre browse in a book library keeps the book types', () async {
    final api = _RecordingItemsApi()..collectionType = 'books';
    final vm = await _viewModel(
      api,
      libraryId: 'book-library-id',
      genreId: 'scifi-genre-id',
    );
    addTearDown(vm.dispose);

    await vm.load();

    expect(api.includeItemTypes, ['Book', 'Audio', 'AudioBook']);
  });

  test('genre browse outside the video libraries is left unscoped', () async {
    for (final collectionType in ['audiobooks', 'musicvideos', 'homevideos']) {
      final api = _RecordingItemsApi()..collectionType = collectionType;
      final vm = await _viewModel(
        api,
        libraryId: 'lib-$collectionType',
        genreId: 'g1',
      );

      await vm.load();

      expect(api.includeItemTypes, isNull, reason: collectionType);
      vm.dispose();
    }
  });
}
