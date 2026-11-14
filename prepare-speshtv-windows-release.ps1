param(
    [switch]$PublicRelease,
    [string]$IsccPath,
    [string]$CorrespondingSourceArchive,
    [switch]$ComplianceReviewed,
    [ValidatePattern('^[a-z0-9-]*$')][string]$CandidateLabel = ''
)
$ErrorActionPreference = 'Stop'
$release = Join-Path $PSScriptRoot 'build/windows/x64/runner/Release'
$exe = Join-Path $release 'SpeshTV.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Build SpeshTV Windows first.' }
$version = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
if ($version -notmatch '^\d+\.\d+\.\d+\+\d+$') { throw 'Unexpected executable version.' }
$signature = Get-AuthenticodeSignature -LiteralPath $exe
if ($PublicRelease) {
    if (!$ComplianceReviewed) { throw 'Public release requires a completed licensing, privacy and clean-PC review.' }
    if ($signature.Status -ne 'Valid' -or !$signature.TimeStamperCertificate) {
        throw 'Public release requires a valid trusted, timestamped executable signature.'
    }
    if (!$CorrespondingSourceArchive -or !(Test-Path -LiteralPath $CorrespondingSourceArchive -PathType Leaf)) {
        throw 'Provide the reviewed corresponding-source archive for this release.'
    }
    if (!$IsccPath -or !(Test-Path -LiteralPath $IsccPath -PathType Leaf)) { throw 'Provide the Inno Setup compiler path.' }
}
$kind = if ($PublicRelease) { 'public' } else { 'unsigned-candidate' }
$label = if ($CandidateLabel) { "$CandidateLabel-" } else { '' }
$output = Join-Path $PSScriptRoot "build/windows/distribution/$version-$label$kind"
if (Test-Path -LiteralPath $output) { throw 'Release output already exists; preserve it and use a new build version.' }
$payload = Join-Path $output 'SpeshTV'
New-Item -ItemType Directory -Path $payload -Force | Out-Null
Get-ChildItem -LiteralPath $release -File | Where-Object {
    $_.Extension -eq '.dll' -or $_.Name -eq 'SpeshTV.exe'
} | Copy-Item -Destination $payload
Copy-Item -LiteralPath (Join-Path $release 'data') -Destination $payload -Recurse
foreach ($name in @('LICENSE', 'FORK.md', 'WINDOWS_SPESHTV.md', 'WINDOWS_DISTRIBUTION.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $payload
}
if ($CorrespondingSourceArchive) {
    Copy-Item -LiteralPath $CorrespondingSourceArchive -Destination $output
}
# The app's generated Flutter notices remain in data/flutter_assets/NOTICES.Z.
$notices = Join-Path $payload 'THIRD_PARTY_NOTICES'
New-Item -ItemType Directory -Path $notices | Out-Null
$vcpkg = Join-Path $PSScriptRoot '.toolchains/vcpkg/installed/x64-windows/share'
if (Test-Path -LiteralPath $vcpkg) {
    Get-ChildItem -LiteralPath $vcpkg -Directory | ForEach-Object {
        $license = Join-Path $_.FullName 'copyright'
        if (Test-Path -LiteralPath $license) {
            Copy-Item -LiteralPath $license -Destination (Join-Path $notices ($_.Name + '.txt'))
        }
    }
}
if ($PublicRelease) {
    & $IsccPath "/DReleaseDir=$payload" "/DOutputDir=$output" "/DAppVersion=$($version.Split('+')[0])" (Join-Path $PSScriptRoot 'windows/speshtv-installer.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
    # Sign separately, then verify and hash again. Never publish an unsigned installer.
}
$zip = Join-Path $output "SpeshTV-Windows-x64-$kind.zip"
Compress-Archive -Path $payload -DestinationPath $zip
$inventory = Get-ChildItem -LiteralPath $payload -Recurse -File | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring($payload.Length + 1).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
}
[ordered]@{
    version = $version
    publicReady = $false
    executableSignature = $signature.Status.ToString()
    defenderScan = 'Not verified'
    installerSignature = 'Not verified'
    files = @($inventory)
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'release-manifest.json') -Encoding UTF8
Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Extension -in @('.zip', '.exe') } | ForEach-Object {
    "$( (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash )  $($_.Name)"
} | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ASCII
Write-Output "Staged release for review: $output"
