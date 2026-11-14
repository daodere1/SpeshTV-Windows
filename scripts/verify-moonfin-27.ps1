param([switch]$Tests, [switch]$SpeshClient, [switch]$SkipSetup, [string[]]$TestPaths)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path (Split-Path $root -Parent) -Parent
if (Test-Path V:\) { throw 'V: is in use.' }
& subst V: $workspace
try {
    $env:PUB_CACHE = 'V:\plugin-work\toolchains\pub-cache'
    $env:GIT_CONFIG_COUNT = '2'
    $env:GIT_CONFIG_KEY_0 = 'safe.directory'
    $env:GIT_CONFIG_VALUE_0 = $root.Replace('\','/')
    $env:GIT_CONFIG_KEY_1 = 'core.longpaths'
    $env:GIT_CONFIG_VALUE_1 = 'true'
    Push-Location 'V:\SpeshMedia\moonfin-android'
    try {
        $flutter = (& cmd /c 'for %I in ("V:\SpeshMedia\moonfin-android\.toolchains\flutter-3.47.2\bin\flutter.bat") do @echo %~sI').Trim()
        if (!$SkipSetup) {
        & cmd /c "`"$flutter`" pub get > .native/moonfin-27-dependencies.log 2>&1"
        if ($LASTEXITCODE) { throw 'Dependency resolution failed. See .native/moonfin-27-dependencies.log.' }
        & cmd /c "`"$flutter`" gen-l10n > .native/moonfin-27-l10n.log 2>&1"
        if ($LASTEXITCODE) { throw 'Localization generation failed.' }
        }
        if ($Tests) {
            if (!$TestPaths) { $TestPaths = @('test') }
            $defines = if ($SpeshClient) { '--dart-define=SPESHMEDIA_CLIENT=true' } else { '' }
            $paths = ($TestPaths | ForEach-Object { '"' + $_ + '"' }) -join ' '
            $label = if ($SpeshClient) { 'spesh-tests' } else { 'tests' }
            & cmd /c "`"$flutter`" test $defines $paths > .native/moonfin-27-$label.log 2>&1"
        } else {
            & cmd /c "`"$flutter`" analyze lib packages/playback_core/lib packages/playback_jellyfin/lib packages/server_jellyfin/lib --no-fatal-infos --no-fatal-warnings > .native/moonfin-27-analysis.log 2>&1"
        }
        Write-Output "Verification exit: $LASTEXITCODE"
    } finally { Pop-Location }
} finally { & subst V: /D }
