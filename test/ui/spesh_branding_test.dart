import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';

void main() {
  test('default skin and exit prompt use SpeshTV', () {
    final strings = AppLocalizationsEn();
    expect(strings.appTitle, 'SpeshTV');
    expect(strings.themeMoonfin, 'SpeshTV');
    expect(strings.exitApp, 'Exit SpeshTV?');
    expect(strings.playInMoonfin, 'Play in SpeshTV');
  });
  test('translations have no legacy UI brand and retain upstream URLs', () {
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in data.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final value = entry.value as String;
        if (value.contains('http://') || value.contains('https://')) continue;
        expect(value.toLowerCase(), isNot(contains('moonfin')),
          reason: '${file.path}: ${entry.key}');
      }
    }
    final english = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync());
    expect(english['sourceCodeUrl'], 'https://github.com/Moonfin-Client/Moonfin-Core');
  });
}
