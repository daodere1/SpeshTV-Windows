import 'aggregated_item.dart';

enum SearchSource { all, local, vod, live }

List<AggregatedItem> matchSearchChannels(
  List<AggregatedItem> channels, String query, {int limit = 24}
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty || q.startsWith('studio:')) return const [];
  int rank(AggregatedItem channel) {
    final number = channel.rawData['ChannelNumber']?.toString() ?? '';
    final name = channel.name.toLowerCase();
    final program = channel.rawData['CurrentProgram'];
    final programName = program is Map
        ? program['Name']?.toString().toLowerCase() ?? '' : '';
    if (number == q) return 0;
    if (name == q) return 1;
    if (name.startsWith(q)) return 2;
    if (name.contains(q)) return 3;
    if (programName.contains(q)) return 4;
    return 5;
  }
  final matches = channels.where((channel) => rank(channel) < 5).toList();
  matches.sort((a, b) {
    final ranked = rank(a).compareTo(rank(b));
    if (ranked != 0) return ranked;
    final left = double.tryParse(a.rawData['ChannelNumber']?.toString() ?? '');
    final right = double.tryParse(b.rawData['ChannelNumber']?.toString() ?? '');
    if (left != null && right != null) return left.compareTo(right);
    return a.name.compareTo(b.name);
  });
  return matches.take(limit).toList();
}

bool isVodLibrary(String name) =>
    RegExp(r'(^|[^a-z0-9])vod([^a-z0-9]|$)', caseSensitive: false)
        .hasMatch(name);

String searchIdentityTitle(String title) {
  final suffix = RegExp(
    r'\s*\((?:\d{4}(?:\s*-\s*\d{4})?|english|spanish|french|german|italian|portuguese|chinese|mandarin|cantonese|japanese|korean|hindi|multi(?: audio)?)\)\s*$',
    caseSensitive: false,
  );
  var value = title.trim();
  while (suffix.hasMatch(value)) {
    value = value.replaceFirst(suffix, '').trim();
  }
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool sameSearchTitle(AggregatedItem a, AggregatedItem b) {
  if (a.serverId != b.serverId || a.type != b.type) return false;
  if (a.id.isNotEmpty && a.id == b.id) return true;
  if (!const {'Movie', 'Series', 'MusicVideo'}.contains(a.type)) return false;
  Map<String, String> ids(AggregatedItem item) => {
    for (final entry in item.providerIds.entries)
      if (const {'tmdb', 'tvdb', 'imdb'}.contains(entry.key.toLowerCase()) &&
          entry.value.trim().isNotEmpty)
        entry.key.toLowerCase(): entry.value.trim().toLowerCase(),
  };
  final left = ids(a);
  final right = ids(b);
  final common = left.keys.where(right.containsKey).toList();
  if (common.isNotEmpty) return common.every((key) => left[key] == right[key]);
  return a.name.trim().isNotEmpty && a.productionYear != null &&
      a.productionYear == b.productionYear &&
      searchIdentityTitle(a.name) == searchIdentityTitle(b.name);
}

List<AggregatedItem> preferLocalSearchResults(List<AggregatedItem> items) {
  final groups = <List<AggregatedItem>>[];
  for (final item in items) {
    // Pairwise matching prevents an ID-less result joining conflicting IDs.
    final index = groups.indexWhere((g) => g.every((i) => sameSearchTitle(i, item)));
    if (index < 0) {
      groups.add([item]);
    } else {
      groups[index].add(item);
    }
  }
  return groups.map((g) => g.firstWhere(
    (i) => i.rawData['SpeshSource'] == 'local', orElse: () => g.first,
  )).toList();
}
