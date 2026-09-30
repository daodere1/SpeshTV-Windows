import 'dart:convert';
import 'package:jellyfin_preference/jellyfin_preference.dart';

String speshViewScope(String server, String? user, String view) =>
    'spesh_view_v1_${jsonEncode([server, user ?? '', view])}';

Preference<String> speshGuidePreference(String server, String? user) =>
    Preference(key: speshViewScope(server, user, 'guide'), defaultValue: '');

class SpeshGuideView {
  final String country, package, tag, filter;
  const SpeshGuideView({this.country = '', this.package = '', this.tag = '', this.filter = 'all'});

  factory SpeshGuideView.decode(String value) {
    try {
      final data = jsonDecode(value);
      if (data is! Map) return const SpeshGuideView();
      String read(String key, [String fallback = '']) =>
          data[key] is String ? data[key] as String : fallback;
      return SpeshGuideView(country: read('country'), package: read('package'),
          tag: read('tag'), filter: read('filter', 'all'));
    } catch (_) {
      return const SpeshGuideView();
    }
  }

  String encode() => jsonEncode({'country': country, 'package': package, 'tag': tag, 'filter': filter});
}
