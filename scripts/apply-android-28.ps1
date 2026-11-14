$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root '.native/upstream-2.8.0'
$backup = Join-Path $root '.native/before-android-28'
if (Test-Path -LiteralPath $backup) { throw 'Android snapshot already exists; refusing to overwrite it.' }
New-Item -ItemType Directory -Path $backup | Out-Null
$entries = Get-Content (Join-Path $stage 'manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $entries) {
    if ($entry.path -notmatch '^android/') { continue }
    $local = Join-Path $root $entry.path
    if (Test-Path -LiteralPath $local -PathType Leaf) {
        $saved = Join-Path $backup $entry.path
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $saved
    }
    if ($entry.status -ne 'clean') { continue }
    $merged = Join-Path $stage "merged/$($entry.path)"
    if (!(Test-Path -LiteralPath $merged)) { throw "Missing staged file: $($entry.path)" }
    New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
    Copy-Item -LiteralPath $merged -Destination $local
    Write-Output "Applied $($entry.path)"
}
Copy-Item -LiteralPath (Join-Path $root 'pubspec.yaml') -Destination (Join-Path $backup 'pubspec.yaml')
Write-Output 'Android snapshot complete. Conflict files left unchanged for manual reconciliation.'
