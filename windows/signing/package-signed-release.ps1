param(
    [Parameter(Mandatory)][ValidateSet('Prepare','Package','Finalize')][string]$Phase,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [Parameter(Mandatory)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$Tag,
    [string]$ExpectedPublisher,
    [string]$IsccPath
)
$ErrorActionPreference = 'Stop'
$version = $Tag.Substring(1)
$work = [IO.Path]::GetFullPath($WorkDirectory)
$payload = Join-Path $work 'payload/SpeshTV'
$app = Join-Path $payload 'SpeshTV.exe'
$output = Join-Path $work 'signed'
$installer = Join-Path $output "SpeshTV-Windows-$version-Setup.exe"
function Assert-Signature([string]$File) {
    if (!$ExpectedPublisher) { throw 'Expected publisher subject is required.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $File
    if ($signature.Status -ne 'Valid' -or !$signature.TimeStamperCertificate) {
        throw "A trusted, timestamped signature is required: $File"
    }
    if ($signature.SignerCertificate.Subject -ne $ExpectedPublisher) {
        throw "Unexpected signing publisher: $File"
    }
    return $signature
}
if ($Phase -eq 'Prepare') {
    $zip = Join-Path $work "SpeshTV-Windows-$version-Portable.zip"
    $sums = Get-Content -LiteralPath (Join-Path $work 'SHA256SUMS.txt')
    $name = [IO.Path]::GetFileName($zip)
    $entries = @($sums | Where-Object { $_ -match ('^[0-9a-fA-F]{64}\s+\*?' + [regex]::Escape($name) + '$') })
    if ($entries.Count -ne 1) { throw 'Exactly one input archive checksum is required.' }
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $entries[0].Substring(0,64)) {
        throw 'Input archive checksum mismatch.'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    $root = [IO.Path]::GetFullPath((Join-Path $work 'payload')) + [IO.Path]::DirectorySeparatorChar
    try {
        foreach ($entry in $archive.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
            if (!$target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Unsafe archive path.'
            }
        }
    } finally { $archive.Dispose() }
    if (Test-Path -LiteralPath (Join-Path $work 'payload')) { throw 'Use a fresh signing workspace.' }
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $work 'payload')
    $actualVersion = (Get-Item -LiteralPath $app).VersionInfo.FileVersion
    if ($actualVersion -notmatch ('^' + [regex]::Escape($version) + '\+\d+$')) {
        throw 'Executable version does not match release tag.'
    }
    if (!(Test-Path -LiteralPath (Join-Path $payload 'LICENSE'))) { throw 'License missing from payload.' }
    New-Item -ItemType Directory -Path $output | Out-Null
    return
}
$appSignature = Assert-Signature $app
if ($Phase -eq 'Package') {
    if (!$IsccPath -or !(Test-Path -LiteralPath $IsccPath)) { throw 'Supply the Inno Setup compiler.' }
    & $IsccPath "/DReleaseDir=$payload" "/DOutputDir=$output" "/DAppVersion=$version" "/DNumericVersion=$version" "/DOutputName=SpeshTV-Windows-$version-Setup" (Join-Path $PSScriptRoot '../speshtv-installer.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
    if (!(Test-Path -LiteralPath $installer)) { throw 'Installer output missing.' }
    return
}
$installerSignature = Assert-Signature $installer
if ($installerSignature.SignerCertificate.Subject -ne $appSignature.SignerCertificate.Subject) {
    throw 'App and installer publishers differ.'
}
Compress-Archive -LiteralPath $payload -DestinationPath (Join-Path $output "SpeshTV-Windows-$version-Portable.zip")
$verification = [ordered]@{
    version = $version
    publisher = $appSignature.SignerCertificate.Subject
    appSignature = $appSignature.Status.ToString()
    installerSignature = $installerSignature.Status.ToString()
    appThumbprint = $appSignature.SignerCertificate.Thumbprint
    installerThumbprint = $installerSignature.SignerCertificate.Thumbprint
    timestamped = $true
}
$verification | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'SIGNATURES.json') -Encoding utf8
# Hash only final bytes: signing changes the app and installer.
Get-ChildItem -LiteralPath $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
} | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
