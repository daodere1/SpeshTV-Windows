import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/spesh_view_preferences.dart';

void main() {
  test('view keys isolate members, servers and libraries', () {
    final key = speshViewScope('server', 'one', 'movies');
    expect(key, isNot(speshViewScope('server', 'two', 'movies')));
    expect(key, isNot(speshViewScope('other', 'one', 'movies')));
    expect(key, isNot(speshViewScope('server', 'one', 'series')));
  });
  test('structured keys cannot collide through separators', () {
    expect(speshViewScope('a|b', 'c', 'd'), isNot(speshViewScope('a', 'b|c', 'd')));
  });
  test('guide choices round trip without transient search or dates', () {
    const view = SpeshGuideView(country: 'PR', package: 'NHL', tag: 'HD', filter: 'favorites');
    final restored = SpeshGuideView.decode(view.encode());
    expect(restored.country, 'PR');
    expect(restored.package, 'NHL');
    expect(restored.tag, 'HD');
    expect(restored.filter, 'favorites');
    expect(view.encode(), isNot(contains('search')));
  });
  test('invalid stored data uses safe defaults', () {
    for (final input in ['bad', '[]', '{"country":42,"filter":null}']) {
      final view = SpeshGuideView.decode(input);
      expect(view.country, '');
      expect(view.filter, 'all');
    }
  });
}
