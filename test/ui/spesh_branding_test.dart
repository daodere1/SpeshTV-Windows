import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';

void main() {
  test('Windows desktop executable and window are SpeshTV branded', () {
    expect(File('windows/CMakeLists.txt').readAsStringSync(), contains('set(BINARY_NAME "SpeshTV")'));
    final runner = File('windows/runner/main.cpp').readAsStringSync();
    expect(runner, contains('L"SpeshTV YouTube API Test" : L"SpeshTV"'));
    expect(runner, contains('Classes\\\\speshtv'));
    final resource = File('windows/runner/Runner.rc').readAsStringSync();
    expect(resource, contains('"ProductName", "SpeshTV"'));
    expect(resource, contains('speshtv.ico'));
  });
  test('Android 12 splash uses STV artwork in light and dark mode', () {
    for (final folder in ['values-v31', 'values-night-v31']) {
      final xml = File('android/app/src/main/res/$folder/styles.xml').readAsStringSync();
      expect(xml, contains('windowSplashScreenAnimatedIcon">@drawable/speshtv_foreground'));
      expect(xml, isNot(contains('@mipmap/ic_launcher_foreground')));
    }
  });
  test('bundled Spesh palettes have distinct names and readable focus text', () {
    for (final entry in {'speshflix': 'SpeshFlix', 'speshprime': 'SpeshPrime', 'speshapple': 'SpeshApple'}.entries) {
      final json = jsonDecode(File('assets/themes/${entry.key}.json').readAsStringSync());
      expect(json['id'], entry.key);
      expect(json['displayName'], entry.value);
      expect(json['colors']['accent'], isNot(json['colors']['onAccent']));
    }
  });
  test('Android launchers retain the STV icon and TV banner', () {
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final tv = File('android/app/src/androidTv/AndroidManifest.xml').readAsStringSync();
    expect(main, contains('android:icon="@drawable/speshtv_icon"'));
    expect(main, contains('android:roundIcon="@drawable/speshtv_icon"'));
    expect(tv, contains('android:icon="@drawable/speshtv_icon"'));
    expect(tv, contains('android:banner="@drawable/speshtv_tv_banner"'));
    final adaptive = File('android/app/src/main/res/drawable-v26/speshtv_icon.xml')
        .readAsStringSync();
    expect(adaptive, contains('<adaptive-icon'));
    expect(adaptive, contains('@drawable/speshtv_foreground'));
  });
  test('default skin and exit prompt use SpeshTV', () {
    final strings = AppLocalizationsEn();
    expect(strings.appTitle, 'SpeshTV');
    expect(strings.themeMoonfin, 'SpeshTV');
    expect(strings.exitApp, 'Exit SpeshTV?');
    expect(strings.playInMoonfin, 'Play in SpeshTV');
  });
  test('translations use SpeshTV branding and the fork source URL', () {
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
    expect(english['sourceCodeUrl'], 'https://github.com/daodere1/SpeshTV-Windows');
  });
}
