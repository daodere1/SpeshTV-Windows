import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/anime_marker_repository.dart';

class SpeshAnimeBadges extends StatefulWidget {
  const SpeshAnimeBadges({
    super.key,
    required this.seriesId,
    required this.itemId,
    this.season = false,
  });
  final String? seriesId;
  final String itemId;
  final bool season;

  @override
  State<SpeshAnimeBadges> createState() => _SpeshAnimeBadgesState();
}

class _SpeshAnimeBadgesState extends State<SpeshAnimeBadges> {
  Future<AnimeEpisodeMarker?>? _marker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpeshAnimeBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesId != widget.seriesId ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.season != widget.season) {
      _load();
    }
  }

  void _load() {
    final id = widget.seriesId;
    if (id == null ||
        id.isEmpty ||
        !GetIt.instance.isRegistered<AnimeMarkerRepository>()) {
      _marker = null;
      return;
    }
    final repository = GetIt.instance<AnimeMarkerRepository>();
    final itemId = widget.itemId;
    final season = widget.season;
    _marker = repository.getForSeries(id).then((_) {
      if (season) {
        final audio = repository.peekSeason(seriesId: id, seasonId: itemId);
        return audio == null
            ? null
            : AnimeEpisodeMarker(kind: null, recap: false, audio: audio);
      }
      return repository.peek(seriesId: id, episodeId: itemId);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnimeEpisodeMarker?>(
    future: _marker,
    builder: (context, snapshot) =>
        snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null
        ? const SizedBox.shrink()
        : SpeshAnimeMarkerLabels(marker: snapshot.data!),
  );
}

class SpeshAnimeMarkerLabels extends StatelessWidget {
  const SpeshAnimeMarkerLabels({
    super.key,
    required this.marker,
    this.compact = false,
  });
  final AnimeEpisodeMarker marker;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labels = <(String, Color)>[
      if (marker.kind != null)
        switch (marker.kind!) {
          AnimeEpisodeKind.mangaCanon => (
            'Manga canon',
            Colors.lightBlueAccent,
          ),
          AnimeEpisodeKind.animeCanon => ('Anime canon', Colors.greenAccent),
          AnimeEpisodeKind.mixed => ('Mixed', Colors.amberAccent),
          AnimeEpisodeKind.filler => ('Filler', Colors.redAccent),
        },
      if (marker.recap) ('Recap', Colors.orangeAccent),
      if (marker.audio != null)
        switch (marker.audio!) {
          AnimeAudioKind.subbed => ('Subbed', Colors.lightBlueAccent),
          AnimeAudioKind.dubbed => ('Dubbed', Colors.greenAccent),
          AnimeAudioKind.subbedAndDubbed => (
            'Subbed + dubbed',
            Colors.tealAccent,
          ),
        },
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = compact && constraints.maxWidth.isFinite
            ? (constraints.maxWidth / 20).clamp(8.0, 10.0)
            : 11.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: compact ? 3 : 6,
            runSpacing: compact ? 2 : 4,
            children: [
              for (final label in labels)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 6,
                    vertical: compact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: compact
                        ? Colors.black87
                        : label.$2.withValues(alpha: 0.12),
                    border: Border.all(color: label.$2.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    label.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.1,
                      color: label.$2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SpeshAnimeItemAudioBadge extends StatefulWidget {
  const SpeshAnimeItemAudioBadge({
    super.key,
    required this.itemId,
    this.seriesId,
  });
  final String itemId;
  final String? seriesId;

  @override
  State<SpeshAnimeItemAudioBadge> createState() =>
      _SpeshAnimeItemAudioBadgeState();
}

class _SpeshAnimeItemAudioBadgeState extends State<SpeshAnimeItemAudioBadge> {
  Future<AnimeEpisodeMarker?>? _audio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpeshAnimeItemAudioBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.seriesId != widget.seriesId) {
      _load();
    }
  }

  void _load() {
    final itemId = widget.itemId;
    final seriesId = widget.seriesId;
    if (!GetIt.instance.isRegistered<AnimeMarkerRepository>() ||
        itemId.isEmpty) {
      _audio = null;
      return;
    }
    final repository = GetIt.instance<AnimeMarkerRepository>();
    _audio = () async {
      final audioFuture = repository.getForItem(itemId);
      AnimeEpisodeMarker? marker;
      if (seriesId != null && seriesId.isNotEmpty) {
        await repository.getForSeries(seriesId);
        marker = repository.peek(seriesId: seriesId, episodeId: itemId);
      }
      final audio = await audioFuture;
      return AnimeEpisodeMarker(
        kind: marker?.kind,
        recap: marker?.recap ?? false,
        audio: marker?.audio ?? audio,
      );
    }();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnimeEpisodeMarker?>(
    future: _audio,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.data == null) {
        return const SizedBox.shrink();
      }
      return SpeshAnimeMarkerLabels(marker: snapshot.data!, compact: true);
    },
  );
}
