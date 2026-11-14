import '../data/services/seerr/seerr_api_models.dart';

List<String> seerrTrailerCandidates(
  SeerrVideo preferred,
  List<SeerrVideo> videos,
) {
  final urls = <String>{};
  for (final video in [
    preferred,
    ...videos.where(
      (v) => ['trailer', 'teaser'].contains(v.type?.toLowerCase()),
    ),
  ]) {
    final key = video.key?.trim();
    final url =
        ((video.site?.toLowerCase() == 'youtube' ||
            (video.url?.trim().isEmpty ?? true)) &&
            key != null &&
            key.isNotEmpty)
        ? 'https://www.youtube.com/watch?v=$key'
        : video.url?.trim();
    if (url == null || url.isEmpty) continue;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty)
      continue;
    urls.add(url);
    if (urls.length == 3) break;
  }
  return urls.toList();
}
