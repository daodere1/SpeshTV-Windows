$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$safe = "safe.directory=$($root.Replace('\','/'))"
$stage = Join-Path $root '.toolchains/moonfin-27-integration'
if (Test-Path $stage) { throw 'Integration snapshot already exists.' }
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($tag in @('2.6.0','2.7.0')) {
    & git -c $safe archive $tag -o "$stage/$tag.zip"
    if ($LASTEXITCODE) { throw 'Could not archive upstream.' }
    Expand-Archive "$stage/$tag.zip" "$stage/$tag"
}
$paths = & git -c $safe diff --name-only 2.6.0 2.7.0
$conflicts = @()
$applied = @()
foreach ($path in $paths) {
    if ($path -match '^lib/l10n/app_localizations') { continue }
    if ($path -match '^\.github/|^\.coderabbit|^README|^CONTRIBUTING') { continue }
    $local = Join-Path $root $path
    $base = Join-Path "$stage/2.6.0" $path
    $upstream = Join-Path "$stage/2.7.0" $path
    $backup = Join-Path "$stage/local" $path
    if (Test-Path $local -PathType Leaf) {
        New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $backup
    }
    if (!(Test-Path $upstream)) { $conflicts += $path; continue }
    if (!(Test-Path $local) -or ((Test-Path $base) -and (Get-FileHash $local).Hash -eq (Get-FileHash $base).Hash)) {
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath $upstream -Destination $local
        $applied += $path
        continue
    }
    if (!(Test-Path $base)) { $conflicts += $path; continue }
    $merged = Join-Path "$stage/merged" $path
    New-Item -ItemType Directory -Path (Split-Path $merged) -Force | Out-Null
    Copy-Item -LiteralPath $local -Destination $merged
    & git merge-file $merged $base $upstream
    if ($LASTEXITCODE -eq 0) {
        Copy-Item -LiteralPath $merged -Destination $local
        $applied += $path
    } else { $conflicts += $path }
}
$conflicts | ConvertTo-Json | Set-Content "$stage/conflicts.json"
$applied | ConvertTo-Json | Set-Content "$stage/applied.json"
Write-Output "Applied $($applied.Count) files; $($conflicts.Count) require review. Original affected files preserved in $stage/local."
$conflicts
