import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:server_core/server_core.dart';

import '../../../data/repositories/seerr_repository.dart';
import '../../../data/services/calendar_snapshot_session.dart';
import '../../../data/services/calendar_refresh_loop.dart';
import '../../navigation/route_lifecycle_observer.dart';
import '../../widgets/stable_agenda_list.dart';
import '../../widgets/focus/focusable_wrapper.dart';
import '../../../util/calendar_eastern_time.dart';
import '../../../data/services/plugin_sync_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../navigation/destinations.dart';
import '../../widgets/bounded_network_image.dart';
import '../../widgets/navigation_layout.dart';

ButtonStyle calendarControlStyle() => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? const Color(0xFF25272C)
        : const Color(0xFF151515),
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? const Color(0xFFA3A7B2)
        : const Color(0xFFF3F5F6),
  ),
  side: WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.focused)
          ? const Color(0xFF8ABCF4)
          : states.contains(WidgetState.selected)
          ? const Color(0xFFF3C564)
          : const Color(0xFF3D424C),
      width: states.contains(WidgetState.focused) ? 2 : 1,
    ),
  ),
);

String calendarSourceLabel(String source) => switch (source) {
  'Sonarr' => 'TV',
  'Radarr' => 'Movies',
  'Jellyfin' => 'Library',
  _ => 'Calendar',
};
String calendarReleaseLabel(String kind) => switch (kind) {
  'digitalRelease' => 'Digital release',
  'physicalRelease' => 'Physical release',
  'inCinemas' => 'In cinemas',
  _ => 'Release',
};
String calendarFailureLabel(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403)
      return 'Sign in again or contact your administrator';
    if (code == 404 || code == 503) return 'Calendar connection is unavailable';
  }
  return 'Unavailable. Other entries remain visible; use Refresh to retry';
}

String calendarEntryIdentity(CinematicCalendarEntry entry) =>
    entry.episodeKey ??
    '${entry.mediaIdentity ?? entry.route}|${calendarEasternDate(entry.date, hasAirTime: entry.hasAirTime).toIso8601String()}|${entry.subtitle}';

enum CalendarMediaFilter { all, tv, movies }

List<CinematicCalendarEntry> filterCalendarEntries(
  List<CinematicCalendarEntry> entries,
  CalendarMediaFilter filter,
) => entries
    .where(
      (entry) =>
          filter == CalendarMediaFilter.all ||
          (filter == CalendarMediaFilter.tv ? entry.isTv : !entry.isTv),
    )
    .toList();

class CinematicCalendarEntry {
  const CinematicCalendarEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.route,
    this.imageUrl,
    this.hasAirTime = false,
    this.episodeKey,
    this.timingPriority = 0,
    this.isTv = false,
    this.availabilityLabel,
    this.mediaIdentity,
  });
  final DateTime date;
  final String title;
  final String subtitle;
  final String route;
  final String? imageUrl;
  final bool hasAirTime;
  final String? episodeKey;
  final int timingPriority;
  final bool isTv;
  final String? availabilityLabel;
  final String? mediaIdentity;
}

String? calendarEpisodeKey(String? series, Object? season, Object? episode) {
  final name = series?.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  if (name == null || name.isEmpty || season == null || episode == null)
    return null;
  return '$name|$season|$episode';
}

String? calendarLocalItemId(Map item) {
  final id = item['moonfinItemId']?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}

String? calendarAvailabilityLabel(Map item, {required bool tv}) {
  if (tv) {
    final episode = item['moonfinEpisodeId']?.toString().trim();
    if (episode != null && episode.isNotEmpty) return 'Available';
    return calendarLocalItemId(item) == null ? null : 'Series available';
  }
  return calendarLocalItemId(item) == null ? null : 'Available';
}

String radarrCalendarRoute(Map item) {
  final localId = calendarLocalItemId(item);
  if (localId != null) return Destinations.item(localId);
  final tmdb = item['tmdbId']?.toString();
  return tmdb == null || tmdb.isEmpty || tmdb == '0'
      ? Destinations.searchWith('${item['title'] ?? ''}')
      : Destinations.seerrMedia(tmdb, mediaType: 'movie');
}

String? _mergedAvailability(String? left, String? right) =>
    left == 'Available' || right == 'Available' ? 'Available' : left ?? right;

String sonarrCalendarRoute(Map item) {
  for (final key in ['moonfinEpisodeId', 'moonfinItemId']) {
    final localId = item[key]?.toString();
    if (localId != null && localId.isNotEmpty)
      return Destinations.item(localId);
  }
  final series = item['series'] as Map?;
  final tmdb = series?['tmdbId']?.toString();
  if (tmdb != null && tmdb.isNotEmpty && tmdb != '0') {
    return Destinations.seerrMedia(tmdb, mediaType: 'tv');
  }
  // Sonarr commonly identifies a show by TVDB alone. Keep its airing visible
  // and open title search rather than discarding an otherwise valid timestamp.
  return Destinations.searchWith('${series?['title'] ?? item['title'] ?? ''}');
}

({DateTime date, bool hasTime})? sonarrCalendarDate(Map item) {
  final utc = '${item['airDateUtc'] ?? ''}'.trim();
  final parsed = DateTime.tryParse(utc);
  // An explicit UTC/offset timestamp is authoritative. Never treat a date-only
  // field, or a timestamp without a timezone, as a known viewer-local air time.
  if (parsed != null &&
      RegExp(
        r'T\d{2}:\d{2}.*(?:Z|[+-]\d{2}:?\d{2})$',
        caseSensitive: false,
      ).hasMatch(utc)) {
    return (date: parsed, hasTime: true);
  }
  final day = DateTime.tryParse('${item['airDate'] ?? ''}');
  return day == null
      ? null
      : (date: DateTime(day.year, day.month, day.day), hasTime: false);
}

/// Timed entries are grouped by Eastern days, regardless of the device zone.
List<CinematicCalendarEntry> calendarEntriesForMonth(
  Iterable<CinematicCalendarEntry> entries,
  DateTime month,
) => calendarEntriesForRange(
  entries,
  DateTime(month.year, month.month),
  DateTime(month.year, month.month + 1),
);

List<CinematicCalendarEntry> calendarEntriesForRange(
  Iterable<CinematicCalendarEntry> entries,
  DateTime start,
  DateTime end,
) {
  final selected = <String, CinematicCalendarEntry>{};
  for (final entry in entries) {
    final local = calendarEasternDate(entry.date, hasAirTime: entry.hasAirTime);
    final key =
        entry.episodeKey ??
        '${entry.route}|${local.toIso8601String()}|${entry.subtitle}';
    final prior = selected[key];
    if (prior == null ||
        entry.timingPriority > prior.timingPriority ||
        (entry.hasAirTime && !prior.hasAirTime)) {
      // Prefer the local playback route/artwork while replacing its date-only
      // premiere with the trusted Sonarr airing timestamp and episode details.
      selected[key] = prior == null
          ? entry
          : CinematicCalendarEntry(
              date: entry.date,
              title: entry.title,
              subtitle: entry.subtitle,
              route:
                  prior.route.startsWith('/item/') &&
                      !(entry.route.startsWith('/item/') &&
                          entry.availabilityLabel == 'Available' &&
                          prior.availabilityLabel != 'Available')
                  ? prior.route
                  : entry.route,
              imageUrl: entry.imageUrl ?? prior.imageUrl,
              hasAirTime: entry.hasAirTime,
              episodeKey: key,
              timingPriority: entry.timingPriority,
              isTv: entry.isTv,
              mediaIdentity: entry.mediaIdentity ?? prior.mediaIdentity,
              availabilityLabel: _mergedAvailability(
                entry.availabilityLabel,
                prior.availabilityLabel,
              ),
            );
    } else if (entry.route.startsWith('/item/') &&
        (!prior.route.startsWith('/item/') ||
            (entry.availabilityLabel == 'Available' &&
                prior.availabilityLabel != 'Available'))) {
      selected[key] = CinematicCalendarEntry(
        date: prior.date,
        title: prior.title,
        subtitle: prior.subtitle,
        route: entry.route,
        imageUrl: prior.imageUrl ?? entry.imageUrl,
        hasAirTime: prior.hasAirTime,
        episodeKey: key,
        timingPriority: prior.timingPriority,
        isTv: prior.isTv,
        mediaIdentity: prior.mediaIdentity ?? entry.mediaIdentity,
        availabilityLabel: _mergedAvailability(
          prior.availabilityLabel,
          entry.availabilityLabel,
        ),
      );
    }
  }
  return selected.values.where((entry) {
    final local = calendarEasternDate(entry.date, hasAirTime: entry.hasAirTime);
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(start) && day.isBefore(end);
  }).toList()..sort((a, b) {
    final left = calendarEasternDate(a.date, hasAirTime: a.hasAirTime);
    final right = calendarEasternDate(b.date, hasAirTime: b.hasAirTime);
    final order =
        DateTime.utc(
          left.year,
          left.month,
          left.day,
          left.hour,
          left.minute,
        ).compareTo(
          DateTime.utc(
            right.year,
            right.month,
            right.day,
            right.hour,
            right.minute,
          ),
        );
    return order != 0 ? order : a.date.compareTo(b.date);
  });
}

class CinematicCalendarScreen extends StatefulWidget {
  const CinematicCalendarScreen({super.key});
  @override
  State<CinematicCalendarScreen> createState() =>
      _CinematicCalendarScreenState();
}

class _CinematicCalendarScreenState extends State<CinematicCalendarScreen>
    with WidgetsBindingObserver, RouteAware {
  Timer? _midnightRefresh;
  bool _pendingMidnightRead = false;
  ModalRoute<dynamic>? _observedRoute;
  bool _pageVisible = true;
  bool _foreground = true;
  late final _refreshLoop = CalendarRefreshLoop(
    onRefresh: _load,
    isBusy: () => _calendarRequests.isRefreshing,
  );
  DateTime _month = DateTime(
    calendarEasternNow().year,
    calendarEasternNow().month,
    calendarEasternNow().day,
  );
  List<CinematicCalendarEntry> _entries = [];
  CalendarMediaFilter _mediaFilter = CalendarMediaFilter.all;
  bool _loading = true;
  bool _refreshing = false;
  final _calendarRequests = CalendarSnapshotSession<CinematicCalendarEntry>();
  bool _partialFailure = false;
  final Map<String, String> _sourceFailures = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncVisibility();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _observedRoute) return;
    if (_observedRoute != null) routeLifecycleObserver.unsubscribe(this);
    _observedRoute = route;
    if (route != null) routeLifecycleObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _pageVisible = false;
    _syncVisibility();
  }

  @override
  void didPopNext() {
    _pageVisible = true;
    _syncVisibility();
    _load();
  }

  void _syncVisibility() {
    final active = _pageVisible && _foreground;
    _refreshLoop.setActive(active);
    if (active) {
      _scheduleMidnightRefresh();
    } else {
      _midnightRefresh?.cancel();
      _calendarRequests.pause();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightRefresh?.cancel();
    final now = DateTime.now();
    _midnightRefresh = Timer(
      calendarNextEasternMidnight(now).difference(now) +
          const Duration(seconds: 15),
      () {
        if (!mounted) return;
        if (_calendarRequests.isRefreshing) {
          _pendingMidnightRead = true;
        } else {
          _load();
        } // Core owns the daily schedule refresh.
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncVisibility();
    if (_foreground && _pageVisible) _load();
  }

  void _load() {
    if (!mounted ||
        !_foreground ||
        !_pageVisible ||
        _calendarRequests.isRefreshing)
      return;
    final now = calendarEasternNow();
    _month = DateTime(now.year, now.month, now.day);
    final month = _month;
    setState(() {
      _loading = _entries.isEmpty;
      _refreshing = true;
      _partialFailure = false;
      _sourceFailures.clear();
    });
    final start = month;
    final end = DateTime(start.year, start.month, start.day + 90);
    final client = GetIt.instance<MediaServerClient>();
    final prefs = GetIt.instance<UserPreferences>();
    final sync = GetIt.instance.isRegistered<PluginSyncService>()
        ? GetIt.instance<PluginSyncService>()
        : null;
    final allowed =
        !prefs.get(UserPreferences.kidsModeEnabled) &&
        GetIt.instance.isRegistered<SeerrRepository>();
    final seerrEnabled = allowed && (sync?.seerrAvailable ?? false);
    final sonarrEnabled = allowed && (sync?.sonarrCalendarAvailable ?? false);
    final sources = <String, Future<List<CinematicCalendarEntry>> Function()>{};
    sources['Jellyfin'] = () async {
      final entries = <CinematicCalendarEntry>[];
      final result = await client.itemsApi
          .getItems(
            includeItemTypes: const ['Movie', 'Episode'],
            recursive: true,
            // Include the boundary day even when the browser is outside ET.
            minPremiereDate: DateTime.utc(
              start.year,
              start.month,
              start.day,
            ).subtract(const Duration(days: 1)),
            sortBy: 'PremiereDate',
            sortOrder: 'Ascending',
            limit: 1000,
            fields: 'PremiereDate,SeriesName,ImageTags,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags',
          )
          .timeout(const Duration(seconds: 12));
      for (final item
          in ((result['Items'] as List?) ?? const []).whereType<Map>()) {
        final date = DateTime.tryParse('${item['PremiereDate'] ?? ''}');
        final id = item['Id']?.toString();
        if (date == null || id == null || id.isEmpty) continue;
        final series = item['SeriesName']?.toString();
        final title = item['Name']?.toString() ?? '';
        final tags = item['ImageTags'] as Map?;
        final primary = tags?['Primary']?.toString();
        final backdropTags = item['BackdropImageTags'] as List?;
        final parentTags = item['ParentBackdropImageTags'] as List?;
        final parentId = item['ParentBackdropItemId']?.toString();
        final artwork = backdropTags != null && backdropTags.isNotEmpty
            ? client.imageApi.getBackdropImageUrl(
                id,
                maxWidth: 640,
                tag: backdropTags.first.toString(),
              )
            : parentId != null && parentTags != null && parentTags.isNotEmpty
            ? client.imageApi.getBackdropImageUrl(
                parentId,
                maxWidth: 640,
                tag: parentTags.first.toString(),
              )
            : primary == null
            ? null
            : client.imageApi.getPrimaryImageUrl(
                id,
                maxWidth: 320,
                tag: primary,
              );
        entries.add(
          CinematicCalendarEntry(
            date: DateTime(date.year, date.month, date.day),
            isTv: item['Type'] == 'Episode' || series != null,
            availabilityLabel: 'Available',
            mediaIdentity: 'library:$id',
            title: series ?? title,
            subtitle: series == null ? 'Library' : '$title · Library',
            imageUrl: artwork,
            route: Destinations.item(id),
            episodeKey: calendarEpisodeKey(
              series,
              item['ParentIndexNumber'],
              item['IndexNumber'],
            ),
          ),
        );
      }

      return entries;
    };
    if (seerrEnabled || sonarrEnabled) {
      final repo = GetIt.instance<SeerrRepository>();
      String day(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
      if (sonarrEnabled)
        sources['Sonarr'] = () async {
          final entries = <CinematicCalendarEntry>[];
          final values = await repo
              .getSonarrCalendar(
                start: day(start.subtract(const Duration(days: 1))),
                end: day(end.add(const Duration(days: 1))),
              )
              .timeout(const Duration(seconds: 65));
          for (final item in values.whereType<Map>()) {
            final series = item['series'];
            if (series is! Map) continue;
            final airing = sonarrCalendarDate(item);
            if (airing == null) continue;
            entries.add(
              CinematicCalendarEntry(
                date: airing.date,
                isTv: true,
                availabilityLabel: calendarAvailabilityLabel(item, tv: true),
                hasAirTime: airing.hasTime,
                timingPriority: 2,
                episodeKey: calendarEpisodeKey(
                  series['title']?.toString(),
                  item['seasonNumber'],
                  item['episodeNumber'],
                ),
                title: '${series['title'] ?? ''}',
                subtitle:
                    'S${item['seasonNumber'] ?? 1} · E${item['episodeNumber'] ?? 1} · ${item['title'] ?? ''}',
                imageUrl: _remoteArtwork(series),
                route: sonarrCalendarRoute(item),
              ),
            );
          }

          return entries;
        };
      if (seerrEnabled)
        sources['Radarr'] = () async {
          final entries = <CinematicCalendarEntry>[];
          final values = await repo
              .getRadarrCalendar(start: day(start), end: day(end))
              .timeout(const Duration(seconds: 65));
          for (final item in values.whereType<Map>()) {
            // Calendar APIs can return a film for any release in the interval.
            for (final release in [
              'digitalRelease',
              'physicalRelease',
              'inCinemas',
            ]) {
              final date = DateTime.tryParse('${item[release] ?? ''}');
              if (date == null) continue;
              entries.add(
                CinematicCalendarEntry(
                  date: DateTime(date.year, date.month, date.day),
                  title: '${item['title'] ?? ''}',
                  subtitle: calendarReleaseLabel(release),
                  imageUrl: _remoteArtwork(item),
                  mediaIdentity:
                      'movie:${item['tmdbId'] ?? item['id'] ?? item['title']}',
                  route: radarrCalendarRoute(item),
                  availabilityLabel: calendarAvailabilityLabel(item, tv: false),
                ),
              );
            }
          }

          return entries;
        };
    }
    _calendarRequests.refresh(
      sources: sources,
      scope:
          '${client.baseUrl}|${client.userId}|${client.accessToken.hashCode}|$allowed|$seerrEnabled|$sonarrEnabled',
      preserveRows: true,
      discardOnFailure: (error) =>
          error is DioException &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403),
      onSnapshot: (snapshot) {
        if (!mounted) return;
        final rows = calendarEntriesForRange(
          snapshot.sources.values.expand((rows) => rows),
          start,
          end,
        );
        if (!snapshot.refreshing && _pendingMidnightRead) {
          _pendingMidnightRead = false;
          scheduleMicrotask(_load);
        }
        setState(() {
          _entries = rows;
          _refreshing = snapshot.refreshing;
          _loading = rows.isEmpty && snapshot.refreshing;
          _partialFailure = snapshot.failures.isNotEmpty;
          _sourceFailures
            ..clear()
            ..addAll(
              snapshot.failures.map(
                (name, error) => MapEntry(
                  calendarSourceLabel(name),
                  calendarFailureLabel(error),
                ),
              ),
            );
        });
      },
    );
  }

  @override
  void dispose() {
    _midnightRefresh?.cancel();
    _refreshLoop.dispose();
    if (_observedRoute != null) routeLifecycleObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _calendarRequests.dispose();
    super.dispose();
  }

  int _artworkRank(Map image) {
    switch (image['coverType']?.toString().toLowerCase()) {
      case 'fanart':
        return 0;
      case 'screenshot':
        return 1;
      case 'banner':
        return 2;
      case 'poster':
        return 3;
      default:
        return 4;
    }
  }

  String? _remoteArtwork(Map item) {
    for (final image
        in (((item['images'] as List?) ?? const []).whereType<Map>().toList()
          ..sort((a, b) => _artworkRank(a).compareTo(_artworkRank(b))))) {
      final url = image['remoteUrl']?.toString();
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        return url;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = filterCalendarEntries(_entries, _mediaFilter);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColorScheme.background,
      body: NavigationLayout(
        activeRoute: Destinations.cinematicCalendar,
        showBackButton: true,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 112,
              compact ? 80 : 24,
              24,
              16,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Today & upcoming',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.refresh,
                      style: calendarControlStyle(),
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_partialFailure)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _sourceFailures.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join(' · '),
                        ),
                      ),
                      TextButton(
                        style: calendarControlStyle(),
                        onPressed: () => _load(),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                SizedBox(
                  height: 3,
                  child: _refreshing ? const LinearProgressIndicator() : null,
                ),
                const SizedBox(height: 17),
                Text(
                  'Schedules are cached on the server and refreshed at midnight Eastern (EST/EDT). Times without a supplied air time are marked “Time unavailable”.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CalendarMediaFilters(
                    selected: _mediaFilter,
                    onChanged: (value) => setState(() => _mediaFilter = value),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visibleEntries.isEmpty && _refreshing
                      ? const Center(child: CircularProgressIndicator())
                      : visibleEntries.isEmpty
                      ? Center(
                          child: Text(
                            _partialFailure
                                ? 'Could not load upcoming releases. Use Retry above.'
                                : 'No upcoming releases for this filter.',
                          ),
                        )
                      : StableAgendaList<CinematicCalendarEntry>(
                          items: visibleEntries,
                          viewId: _mediaFilter,
                          identity: calendarEntryIdentity,
                          itemBuilder: (context, entry, prior) {
                            final accent = entry.isTv
                                ? const Color(0xFF8ABCF4)
                                : const Color(0xFFF3C564);
                            final date = calendarEasternDate(
                              entry.date,
                              hasAirTime: entry.hasAirTime,
                            );
                            final previous = prior == null
                                ? null
                                : calendarEasternDate(
                                    prior.date,
                                    hasAirTime: prior.hasAirTime,
                                  );
                            final heading =
                                previous == null || previous.day != date.day;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (heading)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      16,
                                      12,
                                      12,
                                    ),
                                    child: Text(
                                      DateFormat.MMMMEEEEd(
                                        Localizations.localeOf(context)
                                            .toString(),
                                      ).format(date),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Card(
                                    color: const Color(0xFF151515),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(
                                        color: accent.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: CalendarEntryLink(
                                      route: entry.route,
                                      accent: accent,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: SizedBox(
                                                width: compact ? 88 : 160,
                                                height: compact ? 56 : 90,
                                                child: entry.imageUrl == null
                                                    ? const ColoredBox(
                                                        color: Color(
                                                          0xFF25272C,
                                                        ),
                                                        child: Icon(
                                                          Icons.movie_outlined,
                                                        ),
                                                      )
                                                    : BoundedNetworkImage(
                                                        imageUrl:
                                                            entry.imageUrl!,
                                                        maxWidth: 640,
                                                        fit: BoxFit.contain,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 18),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (entry.availabilityLabel !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.check_circle,
                                                            size: 14,
                                                            color: Color(
                                                              0xFF8CDDAB,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              entry
                                                                  .availabilityLabel!,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Color(
                                                                      0xFF8CDDAB,
                                                                    ),
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    entry.subtitle,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                  if (compact)
                                                    Text(
                                                      entry.hasAirTime
                                                          ? '${DateFormat.jm().format(date)} ${date.timeZoneName}'
                                                          : 'Time unavailable',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (!compact)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                ),
                                                child: Text(
                                                  entry.hasAirTime
                                                      ? '${DateFormat.jm().format(date)} ${date.timeZoneName}'
                                                      : 'Time unavailable',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pure view switch: selection never starts a schedule request.
class CalendarMediaFilters extends StatelessWidget {
  const CalendarMediaFilters({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final CalendarMediaFilter selected;
  final ValueChanged<CalendarMediaFilter> onChanged;
  @override
  Widget build(BuildContext context) => SegmentedButton<CalendarMediaFilter>(
    style: calendarControlStyle(),
    selectedIcon: const Icon(Icons.check, color: Color(0xFFF3C564)),
    segments: const [
      ButtonSegment(
        value: CalendarMediaFilter.all,
        icon: Icon(Icons.filter_list),
        label: Text('All'),
      ),
      ButtonSegment(
        value: CalendarMediaFilter.tv,
        icon: Icon(Icons.tv, color: Color(0xFF8ABCF4)),
        label: Text('TV'),
      ),
      ButtonSegment(
        value: CalendarMediaFilter.movies,
        icon: Icon(Icons.movie_outlined, color: Color(0xFFF3C564)),
        label: Text('Movies'),
      ),
    ],
    selected: {selected},
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}

/// Native keyboard/controller activation and focus restoration on details Back.
class CalendarEntryLink extends StatefulWidget {
  const CalendarEntryLink({
    super.key,
    required this.route,
    required this.child,
    required this.accent,
  });
  final String route;
  final Widget child;
  final Color accent;
  @override
  State<CalendarEntryLink> createState() => _CalendarEntryLinkState();
}

class _CalendarEntryLinkState extends State<CalendarEntryLink> {
  final _focus = FocusNode();
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    _focus.requestFocus();
    try {
      await context.push(widget.route);
    } finally {
      if (mounted) {
        _opening = false;
        _focus.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusableWrapper(
    focusNode: _focus,
    onSelect: _open,
    autoScroll: true,
    borderRadius: 24,
    focusColor: widget.accent,
    descendantsAreFocusable: false,
    disableScale: true,
    highlightOnHover: true,
    child: InkWell(
      canRequestFocus: false,
      onTap: _open,
      borderRadius: BorderRadius.circular(24),
      child: widget.child,
    ),
  );
}
