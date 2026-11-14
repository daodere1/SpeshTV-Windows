$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root '.native/upstream-2.8.0'
$backup = Join-Path $root '.native/before-moonfin-28'
if (Test-Path -LiteralPath $backup) { throw 'Backup already exists; do not rerun an integration over changed files.' }
New-Item -ItemType Directory -Path $backup | Out-Null
$manifest = Get-Content (Join-Path $stage 'manifest.json') -Raw | ConvertFrom-Json
$audit = @()
foreach ($entry in $manifest) {
    $path = $entry.path
    if ($path -notmatch '^(lib/|packages/|windows/|native/|assets/|test/|pubspec.yaml$)' -or
        $path -match '^lib/l10n/app_localizations') { continue }
    $local = Join-Path $root $path
    $upstream = Join-Path $stage "2.8.0/$path"
    $base = Join-Path $stage "2.7.0/$path"
    $merged = Join-Path $stage "merged/$path"
    if (Test-Path -LiteralPath $local -PathType Leaf) {
        $saved = Join-Path $backup $path
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $saved
    }
    if ($entry.status -eq 'delete') {
        # Keep deprecated local files until call sites and tests are reconciled.
        $audit += [pscustomobject]@{path=$path; resolution='retained-deprecated-review'}
        continue
    }
    if ($path -match '\.arb$') {
        $remote = Get-Content -LiteralPath $upstream -Raw | ConvertFrom-Json -AsHashtable
        $current = if (Test-Path $local) { Get-Content $local -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
        $old = if (Test-Path $base) { Get-Content $base -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
        foreach ($key in $current.Keys) {
            if (!$old.ContainsKey($key) -or
                (ConvertTo-Json -InputObject $current[$key] -Depth 30 -Compress) -ne
                (ConvertTo-Json -InputObject $old[$key] -Depth 30 -Compress)) {
                $remote[$key] = $current[$key]
            }
        }
        $text = ConvertTo-Json -InputObject $remote -Depth 40
    } elseif ($entry.status -eq 'clean') {
        if (!(Test-Path -LiteralPath $merged)) { throw "Missing staged file: $path" }
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath $merged -Destination $local
        $audit += [pscustomobject]@{path=$path; resolution='clean-three-way'}
        continue
    } else {
        $text = [IO.File]::ReadAllText($merged)
        $pattern = '(?ms)^<<<<<<<[^\n]*\n(.*?)^=======\r?\n(.*?)^>>>>>>>[^\n]*(?:\n|$)'
        $text = [regex]::Replace($text, $pattern, {
            param($match)
            $ours = $match.Groups[1].Value
            $theirs = $match.Groups[2].Value
            if ($ours.TrimStart().StartsWith('import ') -and $theirs.TrimStart().StartsWith('import ')) {
                return (($ours + $theirs).Split("`n") | Select-Object -Unique) -join "`n"
            }
            if ($path -eq 'lib/data/services/youtube_stream_resolver.dart') {
                return $theirs.Replace('_tryInnertube(String videoId) async', '_tryInnertube(String videoId, {int? maxHeight}) async')
            }
            return $ours
        })
    }
    if ($text -match '(?m)^(<<<<<<<|=======|>>>>>>>)') { throw "Unresolved markers in $path" }
    New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
    [IO.File]::WriteAllText($local, $text, [Text.UTF8Encoding]::new($false))
    $audit += [pscustomobject]@{path=$path; resolution='fork-overlap-kept-review-required'}
}
$audit | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $stage 'application-audit.json')
Write-Output "Applied $($audit.Count) paths; originals in $backup. Conflict resolutions require analysis and review."
