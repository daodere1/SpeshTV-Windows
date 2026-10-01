param([switch]$TestOnly, [switch]$AnalyzeOnly)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Test-Path 'S:\') { throw 'S: is already in use. Choose a free temporary build drive.' }
& subst S: $workspace
if ($LASTEXITCODE -ne 0) { throw 'Could not create temporary build drive.' }
try {
$buildRoot = 'S:\SpeshMedia\moonfin-android'
$env:JAVA_HOME = (Get-ChildItem 'S:/SpeshMedia/android/.toolchains' -Directory -Filter 'jdk-17*' | Select-Object -First 1).FullName
$env:ANDROID_HOME = 'C:\Users\daori\AppData\Local\Android\Sdk'
$env:PUB_CACHE = 'S:\plugin-work\toolchains\pub-cache'
$env:GRADLE_USER_HOME = Join-Path $buildRoot '.gradle-home'
$env:GRADLE_OPTS = '-Dorg.gradle.java.home="' + $env:JAVA_HOME + '"'
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'
$flutterPath = 'S:\SpeshMedia\moonfin-android\.toolchains\flutter-3.47.2\bin\flutter.bat'
# Windows native-assets hooks currently misquote a Dart executable path with spaces.
$flutter = (& cmd /c "for %I in (`"$flutterPath`") do @echo %~sI").Trim()
Push-Location $buildRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    if ($AnalyzeOnly) {
        & $flutter analyze lib --no-fatal-infos --no-fatal-warnings 2>&1 | Tee-Object -FilePath '.native/analyze.txt' | Select-String 'error -|issues found|No issues'
    } elseif ($TestOnly) {
        & $flutter test test/ui/spesh_branding_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Branding tests failed.' }
        & $flutter test test/data/services/spesh_browse_dedupe_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Library deduplication tests failed.' }
        & $flutter test test/data/viewmodels/library_browse_filters_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Library browsing tests failed.' }
        & $flutter test test/data/services/spesh_progress_resolver_test.dart test/util/channel_facets_test.dart test/ui/spesh_episode_filters_test.dart test/repositories/spesh_search_repository_test.dart test/repositories/spesh_search_transport_test.dart test/viewmodels/spesh_search_view_model_test.dart test/models/spesh_channel_search_test.dart test/viewmodels/spesh_progress_cache_test.dart test/data/services/progress_cache_store_test.dart test/data/services/progress_refresh_coordinator_test.dart test/viewmodels/live_tv_guide_view_model_test.dart test/playback/spesh_media3_platform_test.dart test/ui/kids_mode_test.dart --dart-define=SPESHMEDIA_CLIENT=true
    } else {
        & $flutter build apk --debug --flavor mobile --dart-define=SPESHMEDIA_CLIENT=true
    }
    if ($LASTEXITCODE -ne 0) { throw 'SpeshMedia build or tests failed.' }
} finally { Pop-Location }
} finally { & subst S: /D }
