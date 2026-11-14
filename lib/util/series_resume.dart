import '../data/models/aggregated_item.dart';

AggregatedItem? savedSeriesEpisode(List<AggregatedItem> episodes) {
  for (final episode in episodes) {
    if (!episode.isPlayed &&
        (episode.playbackPosition ?? Duration.zero) > Duration.zero) {
      return episode;
    }
  }
  return null;
}
