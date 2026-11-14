param([Parameter(Mandatory=$true)][string]$Bundle)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Bundle).Path)
try {
    foreach ($asset in @(
        'base/assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
        'base/assets/flutter_assets/packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
        'base/assets/flutter_assets/packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
        'base/assets/flutter_assets/packages/material_symbols_icons/lib/fonts/MaterialSymbolsSharp.ttf',
        'BUNDLE-METADATA/com.android.tools/r8.json'
    )) {
        if (!$zip.GetEntry($asset)) { throw "Required bundle asset missing: $asset" }
    }
    $entry = $zip.GetEntry('BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map')
    if (!$entry) { throw 'Deobfuscation mapping is missing.' }
    $reader = New-Object IO.StreamReader($entry.Open())
    try { $mapping = $reader.ReadToEnd() } finally { $reader.Dispose() }
    foreach ($class in @(
        'io.flutter.embedding.engine.FlutterJNI',
        'io.flutter.plugins.GeneratedPluginRegistrant',
        'org.moonfin.androidtv.MoonfinCastOptionsProvider',
        'org.moonfin.androidtv.LibretroBridge',
        'androidx.media3.decoder.av1.Dav1dDecoder'
    )) {
        $escaped = [regex]::Escape($class)
        if ($mapping -notmatch "(?m)^$escaped -> $($escaped):") {
            throw "Protected entrypoint was removed or renamed: $class"
        }
    }
} finally { $zip.Dispose() }
$jdk = (Get-ChildItem (Join-Path $PSScriptRoot '../android/.toolchains') -Directory -Filter 'jdk-17*' | Select-Object -First 1).FullName
$verification = & (Join-Path $jdk 'bin/jarsigner.exe') -verify $Bundle
if ($LASTEXITCODE -ne 0 -or !($verification -match '^jar verified\.')) {
    throw 'Bundle signature verification failed.'
}
Write-Output 'Bundle signature, icon fonts, embedded mapping, and protected entrypoints verified.'
