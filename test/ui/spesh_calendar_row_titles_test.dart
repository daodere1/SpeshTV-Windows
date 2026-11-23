import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/home_row.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';
import 'package:moonfin/ui/util/home_row_title_localizer.dart';

void main() {
  test('upcoming rows use friendly localized titles without backend names', () {
    final l10n = AppLocalizationsEn();
    for (final entry in {
      'radarr_calendar': l10n.upcomingMovies,
      'sonarr_calendar': l10n.upcomingSeries,
    }.entries) {
      expect(
        localizeHomeRowTitle(
          row: HomeRow(
            id: entry.key,
            title: 'Backend title',
            rowType: HomeRowType.pluginDynamic,
          ),
          l10n: l10n,
        ),
        entry.value,
      );
    }
  });
}
