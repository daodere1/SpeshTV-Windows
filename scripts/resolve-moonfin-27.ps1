$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root '.toolchains/moonfin-27-integration'
$utf8 = [Text.UTF8Encoding]::new($false)
$keepWhole = @('lib/data/viewmodels/search_view_model.dart','lib/ui/screens/livetv/live_tv_player_screen.dart','lib/data/services/youtube_stream_resolver.dart')
$chooseOurs = @('lib/playback/media_kit_player_backend.dart','lib/ui/screens/home/home_view_model.dart','pubspec.yaml')
foreach ($path in (Get-Content "$stage/remaining.json" -Raw | ConvertFrom-Json)) {
    $local = Join-Path $root $path
    $upstream = Join-Path "$stage/2.7.0" $path
    if (!(Test-Path $upstream)) {
        $resolved = [IO.Path]::GetFullPath($local)
        if (!$resolved.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Outside workspace.' }
        if (Test-Path $resolved) { Remove-Item -LiteralPath $resolved }
        continue
    }
    if ($keepWhole -contains $path) { continue }
    $merged = Join-Path "$stage/normalized/merged" $path
    $content = [IO.File]::ReadAllText($merged)
    $ours = $chooseOurs -contains $path
    $content = [regex]::Replace($content, '(?ms)^<<<<<<<[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>>[^\n]*\n?', {
        param($match)
        if ($ours) { $match.Groups[1].Value } else { $match.Groups[2].Value }
    })
    [IO.File]::WriteAllText($local, $content, $utf8)
}
