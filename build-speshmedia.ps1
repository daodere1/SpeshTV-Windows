param([switch]$TestOnly, [switch]$AnalyzeOnly, [switch]$NativeTests, [switch]$AndroidTv, [switch]$Release, [switch]$AppBundle, [switch]$StoreRelease, [switch]$Clean, [switch]$TvTransformTrace, [string]$TvTestName, [int]$BuildNumber)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$previousStoreBuild = $env:SPESHCAST_STORE_BUILD
$signingVariables = @('SPESHCAST_KEYSTORE', 'SPESHCAST_KEY_ALIAS', 'SPESHCAST_KEY_PASSWORD')
$previousSigning = @{}
foreach ($name in $signingVariables) {
    $previousSigning[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
if ($StoreRelease) {
    if (!$AppBundle -or !$Release) { throw 'StoreRelease requires AppBundle and Release.' }
    if (!(Test-Path (Join-Path $env:LOCALAPPDATA 'SpeshMedia/Signing/speshcast-upload.json'))) {
        throw 'Configure the permanent release upload keystore before building store bundles.'
    }
}
if (Test-Path 'S:\') { throw 'S: is already in use. Choose a free temporary build drive.' }
& subst S: $workspace
if ($LASTEXITCODE -ne 0) { throw 'Could not create temporary build drive.' }
try {
$env:SPESHCAST_STORE_BUILD = if ($StoreRelease) { 'true' } else { 'false' }
if ($StoreRelease) {
    $signing = Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'SpeshMedia/Signing/speshcast-upload.json') -Raw | ConvertFrom-Json
    if (!(Test-Path -LiteralPath $signing.keystore)) { throw 'Upload keystore is missing.' }
    $secret = ConvertTo-SecureString $signing.passwordDpapi
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try {
        $env:SPESHCAST_KEYSTORE = $signing.keystore
        $env:SPESHCAST_KEY_ALIAS = $signing.alias
        $env:SPESHCAST_KEY_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secret.Dispose()
    }
}
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
    if ($Clean) {
        & $flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }
    }
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    if ($NativeTests) {
        # Match release plugin registration before invoking Gradle directly.
        & $flutter build apk --config-only --release --flavor mobile --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Release plugin configuration failed.' }
        Push-Location android
        try {
            & ./gradlew.bat :app:testMobileReleaseUnitTest :app:testAndroidTvReleaseUnitTest :moonfin_native_video:testReleaseUnitTest --console=plain
            if ($LASTEXITCODE -ne 0) { throw 'Native Android release regression tests failed.' }
        } finally { Pop-Location }
    } elseif ($AnalyzeOnly) {
        & $flutter analyze lib --no-fatal-infos --no-fatal-warnings 2>&1 | Tee-Object -FilePath '.native/analyze.txt' | Select-String 'error -|issues found|No issues'
    } elseif ($TestOnly) {
        & $flutter test test/util/remote_activation_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Remote activation tests failed.' }
        & $flutter test test/util/artwork_request_scheduler_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Artwork priority tests failed.' }
        & $flutter test test/data/services/session_request_cache_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Session cache tests failed.' }
        & $flutter test test/ui/spesh_tv_filters_test.dart test/ui/spesh_channel_filters_test.dart test/util/tv_transform_trace_test.dart test/livetv/guide_hero_height_test.dart test/ui/spesh_guide_focus_bands_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Guide filter tests failed.' }
        if ($AndroidTv) {
            $tvFilter = @()
            if ($TvTestName) { $tvFilter = @('--plain-name', $TvTestName) }
            & $flutter test test/util/tv_ui_scale_test.dart test/ui/library_browse_grid_focus_test.dart test/playback/player_overlay_focus_test.dart test/ui/navigation/focus_route_observer_test.dart test/ui/widgets/rtl_dpad_navigation_test.dart test/livetv/guide_navigation_widget_test.dart --dart-define=SPESHMEDIA_CLIENT=true @tvFilter
            if ($LASTEXITCODE -ne 0) { throw 'Android TV navigation tests failed.' }
        }
        & $flutter test test/ui/spesh_branding_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Branding tests failed.' }
        & $flutter test test/data/services/spesh_browse_dedupe_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Library deduplication tests failed.' }
        & $flutter test test/data/viewmodels/library_browse_filters_test.dart --dart-define=SPESHMEDIA_CLIENT=true
        if ($LASTEXITCODE -ne 0) { throw 'Library browsing tests failed.' }
        & $flutter test test/data/services/spesh_progress_resolver_test.dart test/util/channel_facets_test.dart test/ui/spesh_episode_filters_test.dart test/repositories/spesh_search_repository_test.dart test/repositories/spesh_search_transport_test.dart test/viewmodels/spesh_search_view_model_test.dart test/models/spesh_channel_search_test.dart test/viewmodels/spesh_progress_cache_test.dart test/data/services/progress_cache_store_test.dart test/data/services/progress_refresh_coordinator_test.dart test/viewmodels/live_tv_guide_view_model_test.dart test/playback/spesh_media3_platform_test.dart test/ui/kids_mode_test.dart --dart-define=SPESHMEDIA_CLIENT=true
    } else {
        $flavor = if ($AndroidTv) { 'androidTv' } else { 'mobile' }
        $buildMode = if ($Release) { '--release' } else { '--debug' }
        $traceArgs = @()
        if ($TvTransformTrace) { $traceArgs = @('--dart-define=SPESH_TV_TRANSFORM_TRACE=true') }
        if ($BuildNumber -gt 0) { $traceArgs += "--build-number=$BuildNumber" }
        $artifact = if ($AppBundle) { 'appbundle' } else { 'apk' }
        & $flutter build $artifact $buildMode --flavor $flavor --dart-define=SPESHMEDIA_CLIENT=true @traceArgs
    }
    if ($LASTEXITCODE -ne 0) { throw 'SpeshMedia build or tests failed.' }
} finally { Pop-Location }
} finally {
    $env:SPESHCAST_STORE_BUILD = $previousStoreBuild
    foreach ($name in $signingVariables) {
        [Environment]::SetEnvironmentVariable($name, $previousSigning[$name], 'Process')
    }
    & subst S: /D
}
