class ChannelFilterOption {
  const ChannelFilterOption(this.value, this.count);
  final String value;
  final int count;
}

class ChannelFacets {
  const ChannelFacets(this.countries, this.packages, this.tags);
  final Set<String> countries;
  final Set<String> packages;
  final Set<String> tags;

  static const _countries = {
    'PR': 'PR | Puerto Rico', 'DR': 'DR | Dominican Republic',
    'DO': 'DR | Dominican Republic', 'CH': 'CH | China', 'CN': 'CH | China',
    'US': 'US | United States', 'USA': 'US | United States',
    'UK': 'UK | United Kingdom', 'GB': 'UK | United Kingdom',
    'CA': 'CA | Canada', 'MX': 'MX | Mexico', 'ES': 'ES | Spain',
    'FR': 'FR | France', 'DE': 'DE | Germany', 'IT': 'IT | Italy',
    'JP': 'JP | Japan', 'KR': 'KR | South Korea', 'IN': 'IN | India',
    'PH': 'PH | Philippines', 'TW': 'TW | Taiwan', 'HK': 'HK | Hong Kong',
    'BR': 'BR | Brazil', 'PT': 'PT | Portugal', 'AU': 'AU | Australia',
  };

  factory ChannelFacets.fromChannel(String name, Map<String, dynamic> raw) {
    final tags = <String>{};
    // Group tags can contain semicolon-separated genres from imported lineups.
    for (final field in ['Tags', 'Genres']) {
      final values = raw[field];
      if (values is! List) continue;
      for (final value in values.whereType<String>()) {
        tags.addAll(value.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty));
      }
    }
    final countries = <String>{};
    for (final value in [name, ...tags]) {
      final upper = value.trim().toUpperCase();
      final prefix = RegExp(r'^([A-Z]{2,3})(?:\s*[|:\-]|$)').firstMatch(upper)?.group(1);
      final country = _countries[prefix];
      if (country != null) countries.add(country);
      if (upper == 'PUERTO RICO') countries.add('PR | Puerto Rico');
      if (upper == 'DOMINICAN REPUBLIC') countries.add('DR | Dominican Republic');
      if (upper == 'CHINA') countries.add('CH | China');
    }
    final packages = <String>{};
    for (final value in [name, ...tags]) {
      final upper = value.toUpperCase();
      if (RegExp(r'\b(?:CFB|NCAA\s*F)\b|\bCOLLEGE FOOTBALL\b|\bNCAA FOOTBALL\b').hasMatch(upper)) {
        packages.add('College football');
      }
      if (RegExp(r'\b(?:CBB|NCAA\s*B)\b|\bCOLLEGE BASKETBALL\b|\bNCAA BASKETBALL\b|\bMARCH MADNESS\b').hasMatch(upper)) {
        packages.add('College basketball');
      }
      if (RegExp(r'\bCOLLEGE BASEBALL\b|\bNCAA BASEBALL\b').hasMatch(upper)) {
        packages.add('College baseball');
      }
      if (RegExp(r'\bNCAA\b|\bCOLLEGE SPORTS?\b').hasMatch(upper)) {
        packages.add('College sports / NCAA');
      }
    }
    for (final tag in tags) {
      final upper = tag.toUpperCase();
      for (final league in ['NBA', 'NFL', 'MLB', 'NHL', 'UFC']) {
        if (RegExp('\\b$league\\b').hasMatch(upper) && upper.contains('PACKAGE')) packages.add(league);
      }
      if (upper == '1118' || RegExp(r'\bPPV\b|LIVE EVENTS?').hasMatch(upper)) packages.add('PPV / Live events');
    }
    final eventName = name.toUpperCase().replaceFirst(RegExp(r'^[A-Z]{2,3}\s*[|:]\s*'), '');
    if (RegExp(r'^PPV\b').hasMatch(eventName)) packages.add('PPV / Live events');
    if (RegExp(r'^ESPN\s*(?:PLUS|\+)').hasMatch(eventName)) packages.add('ESPN+');
    if (RegExp(r'^FLO(?:SPORTS|\s|:)').hasMatch(eventName)) packages.add('FloSports');
    return ChannelFacets(countries, packages, tags);
  }
}

List<ChannelFilterOption> channelFilterOptions(Iterable<Set<String>> values) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final channel in values) {
    final seen = <String>{};
    for (final label in channel) {
      final key = label.toLowerCase();
      if (!seen.add(key)) continue;
      labels.putIfAbsent(key, () => label);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  return counts.entries.map((e) => ChannelFilterOption(labels[e.key]!, e.value)).toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
}
