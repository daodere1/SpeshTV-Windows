param([string]$CandidateDirectory, [string]$IsccPath)
$ErrorActionPreference = 'Stop'
if (!$CandidateDirectory) {
    $latest = Get-ChildItem (Join-Path $PSScriptRoot 'build/windows/distribution') -Directory |
        Where-Object Name -Like '*-unsigned-candidate' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (!$latest) { throw 'Stage an unsigned candidate first.' }
    $CandidateDirectory = $latest.FullName
}
$CandidateDirectory = (Resolve-Path -LiteralPath $CandidateDirectory).Path
$manifestPath = Join-Path $CandidateDirectory 'release-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.publicReady) { throw 'Use the signed public-release pipeline for public artifacts.' }
$payload = Join-Path $CandidateDirectory 'SpeshTV'
foreach ($entry in $manifest.files) {
    $file = [IO.Path]::GetFullPath((Join-Path $payload $entry.path))
    if (!$file.StartsWith($payload + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid manifest path' }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw "Staged payload changed: $($entry.path)"
    }
}
if (!$IsccPath) { $IsccPath = Join-Path $PSScriptRoot '.toolchains/inno-setup-6/ISCC.exe' }
if (!(Test-Path -LiteralPath $IsccPath)) { throw 'Supply an Inno Setup 6 compiler path.' }
$version = $manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+\+\d+$') { throw 'Invalid candidate version' }
$name = "SpeshTV-$version-Setup-unsigned"
if (Test-Path U:\) { throw 'U: is in use; cannot map installer staging.' }
& subst U: $CandidateDirectory
if ($LASTEXITCODE -ne 0) { throw 'Cannot map installer staging.' }
try {
    & $IsccPath '/DReleaseDir=U:\SpeshTV' '/DOutputDir=U:\' "/DAppVersion=$version" "/DNumericVersion=$($version.Split('+')[0])" "/DOutputName=$name" (Join-Path $PSScriptRoot 'windows/speshtv-installer.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
} finally { & subst U: /D }
$installer = Join-Path $CandidateDirectory ($name + '.exe')
$manifest | Add-Member -NotePropertyName installerSignature -NotePropertyValue (Get-AuthenticodeSignature -LiteralPath $installer).Status.ToString() -Force
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Get-ChildItem -LiteralPath $CandidateDirectory -File | Where-Object { $_.Extension -in @('.zip', '.exe') } | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)  $($_.Name)"
} | Set-Content -LiteralPath (Join-Path $CandidateDirectory 'SHA256SUMS.txt') -Encoding ASCII
Write-Output "Unsigned test installer: $installer"
