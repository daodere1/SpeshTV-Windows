param([switch]$TestOnly, [switch]$NoAnnouncements,
    [string]$ToolchainRoot = (Join-Path $PSScriptRoot '.toolchains'),
    [string]$PubCache)
$ErrorActionPreference = 'Stop'
$buildParent = Split-Path $PSScriptRoot -Parent
if (Test-Path V:\) { throw 'V: is already in use.' }
& subst V: $buildParent
if ($LASTEXITCODE -ne 0) { throw 'Could not map build workspace.' }
try {
    $root = Join-Path 'V:\' (Split-Path $PSScriptRoot -Leaf)
    if ($PubCache) { $env:PUB_CACHE = $PubCache }
    $env:GIT_CONFIG_COUNT = '2'
    $env:GIT_CONFIG_KEY_0 = 'safe.directory'
    $env:GIT_CONFIG_VALUE_0 = $PSScriptRoot.Replace('\','/')
    $env:GIT_CONFIG_KEY_1 = 'core.longpaths'
    $env:GIT_CONFIG_VALUE_1 = 'true'
    $env:VCPKG_ROOT = Join-Path $ToolchainRoot 'vcpkg'
    $env:PATH = $ToolchainRoot + ';' + $env:PATH
    $flutterPath = Join-Path $ToolchainRoot 'flutter-3.47.2/bin/flutter.bat'
    $flutter = (& cmd /c "for %I in (`"$flutterPath`") do @echo %~sI").Trim()
    Push-Location $root
    try {
        & cmd /c "`"$flutter`" pub get 2>&1"
        if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
        & cmd /c "`"$flutter`" gen-l10n 2>&1"
        if ($LASTEXITCODE -ne 0) { throw 'Localization generation failed.' }
        if ($TestOnly) {
            & cmd /c "`"$flutter`" test test/ui/spesh_branding_test.dart test/data/services/deep_link_service_test.dart test/playback/media_kit_open_request_test.dart test/playback/confirm_seek_held_test.dart test/playback/playback_manager_paused_reresolve_test.dart --dart-define=SPESHMEDIA_CLIENT=true 2>&1"
            if ($LASTEXITCODE -ne 0) { throw 'Desktop branding or link tests failed.' }
            return
        }
        & ./generate-speshtv-windows-icon.ps1
        if (!(Test-Path (Join-Path $env:VCPKG_ROOT 'vcpkg.exe'))) {
            & (Join-Path $env:VCPKG_ROOT 'bootstrap-vcpkg.bat') -disableMetrics
            if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed.' }
        }
        if (!(Test-Path (Join-Path $env:VCPKG_ROOT 'installed/x64-windows/lib/archive.lib'))) {
            & (Join-Path $env:VCPKG_ROOT 'vcpkg.exe') install libarchive:x64-windows --disable-metrics
            if ($LASTEXITCODE -ne 0) { throw 'Windows archive dependency build failed.' }
        }
        $announce = if ($NoAnnouncements) { 'false' } else { 'true' }
        & cmd /c "`"$flutter`" build windows --release --dart-define=SPESHMEDIA_CLIENT=true --dart-define=SPESHTV_ANNOUNCEMENTS=$announce --dart-define=DISTRIBUTION_CHANNEL=speshtv-windows 2>&1"
        if ($LASTEXITCODE -ne 0) { throw 'SpeshTV Windows build failed.' }
        $release = Join-Path $root 'build/windows/x64/runner/Release'
        if (!(Test-Path (Join-Path $release 'SpeshTV.exe'))) { throw 'SpeshTV executable missing.' }
        Copy-Item (Join-Path $env:VCPKG_ROOT 'installed/x64-windows/bin/*.dll') $release
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
        $vsPath = & $vswhere -latest -products * -property installationPath
        $crt = Get-ChildItem (Join-Path $vsPath 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory |
            Where-Object { $_.Parent.Parent.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [Version]$_.Parent.Parent.Name } -Descending |
            Select-Object -First 1
        if (!$crt) { throw 'Visual C++ runtime payload is missing.' }
        Copy-Item (Join-Path $crt.FullName '*.dll') $release -Force
        $variant = if ($NoAnnouncements) { 'no-announce' } else { 'announce' }
        $output = Join-Path $root "build/windows/SpeshTV-Windows-x64-$variant.zip"
        Compress-Archive -Path "$release/*" -DestinationPath $output -Force
        # Bundle only the public bot files. Never package a configured .env.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $botRoot = Join-Path $root 'tools/discord-request-bot'
        $archive = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Update)
        try {
            foreach ($name in @('LICENSE', 'FORK.md', 'WINDOWS_SPESHTV.md', 'WINDOWS_DISTRIBUTION.md')) {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $root $name), $name) | Out-Null
            }
            foreach ($dependency in Get-ChildItem (Join-Path $env:VCPKG_ROOT 'installed/x64-windows/share') -Directory) {
                $notice = Join-Path $dependency.FullName 'copyright'
                if (Test-Path -LiteralPath $notice) {
                    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $notice, "THIRD_PARTY_NOTICES/$($dependency.Name).txt") | Out-Null
                }
            }
            foreach ($name in @('package.json','package-lock.json','.env.example','bot.mjs','interaction-handler.mjs','config.mjs','logic.mjs','register.mjs','README.md','Start-Bot.cmd','Setup-Bot.cmd')) {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $botRoot $name), "Discord-Request-Bot/$name") | Out-Null
            }
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $botRoot 'test') -Filter '*.test.mjs') {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "Discord-Request-Bot/test/$($file.Name)") | Out-Null
            }
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $botRoot 'README-Discord-Requests.md'), 'README-Discord-Requests.md') | Out-Null
        } finally { $archive.Dispose() }
        Write-Output "Portable client: $output"
    } finally { Pop-Location }
} finally { & subst V: /D }
