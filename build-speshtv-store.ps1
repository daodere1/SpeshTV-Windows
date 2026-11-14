param(
    [Parameter(Mandatory)][string]$CandidateDirectory,
    [ValidatePattern('^\d+\.\d+\.\d+\.0$')][string]$StoreVersion = '2.8.0.0'
)
$ErrorActionPreference = 'Stop'
foreach ($part in $StoreVersion.Split('.')) {
    if ([int]$part -gt 65535) { throw 'MSIX version component exceeds 65535.' }
}
$candidate = (Resolve-Path -LiteralPath $CandidateDirectory).Path
$inventory = Get-Content -LiteralPath (Join-Path $candidate 'release-manifest.json') -Raw | ConvertFrom-Json
$source = Join-Path $candidate 'SpeshTV'
foreach ($entry in $inventory.files) {
    $file = [IO.Path]::GetFullPath((Join-Path $source $entry.path))
    if (!$file.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid staged path.' }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw "Staged payload changed: $($entry.path)"
    }
}
$sdk = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Directory |
    Where-Object { $_.Name -match '^10\.0\.\d+\.0$' } |
    Sort-Object { [Version]$_.Name } -Descending | Select-Object -First 1
$makeAppx = Join-Path $sdk.FullName 'x64\makeappx.exe'
if (!(Test-Path -LiteralPath $makeAppx)) { throw 'Windows SDK MakeAppx is required.' }
$output = Join-Path $PSScriptRoot "build/windows/store/$StoreVersion-review"
if (Test-Path -LiteralPath $output) { throw 'Output already exists; preserve it and choose a newer Store version.' }
$payload = Join-Path $output 'payload'
New-Item -ItemType Directory -Path $payload -Force | Out-Null
Get-ChildItem -LiteralPath $source | Copy-Item -Destination $payload -Recurse
if (@(Get-ChildItem -LiteralPath $payload -Filter '*.exe').Count -ne 1 -or
    !(Test-Path -LiteralPath (Join-Path $payload 'SpeshTV.exe'))) { throw 'Unexpected executable in payload.' }
$images = Join-Path $payload 'Images'
New-Item -ItemType Directory -Path $images -Force | Out-Null
Add-Type -AssemblyName System.Drawing
$icon = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'assets/icons/app_icon.png'))
try {
    foreach ($size in @(44, 50, 150)) {
        $bitmap = [Drawing.Bitmap]::new($size, $size)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($icon, 0, 0, $size, $size)
            $bitmap.Save((Join-Path $images "Logo$size.png"), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $icon.Dispose() }
$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
 xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
 xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
 IgnorableNamespaces="uap rescap">
 <Identity Name="SpeshCaster.SpeshTV" Publisher="CN=28D726F4-131C-4CAE-AC94-E02C2A5DFBBB" Version="$StoreVersion" ProcessorArchitecture="x64" />
 <Properties><DisplayName>SpeshTV</DisplayName><PublisherDisplayName>SpeshCaster</PublisherDisplayName><Logo>Images\Logo50.png</Logo></Properties>
 <Resources><Resource Language="en-us" /></Resources>
 <Dependencies><TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" /></Dependencies>
 <Applications><Application Id="SpeshTV" Executable="SpeshTV.exe" EntryPoint="Windows.FullTrustApplication">
  <uap:VisualElements DisplayName="SpeshTV" Description="A media client for your Jellyfin and Emby servers." BackgroundColor="transparent" Square150x150Logo="Images\Logo150.png" Square44x44Logo="Images\Logo44.png" />
  <Extensions><uap:Extension Category="windows.protocol"><uap:Protocol Name="speshtv"><uap:DisplayName>SpeshTV</uap:DisplayName></uap:Protocol></uap:Extension></Extensions>
 </Application></Applications>
 <Capabilities><Capability Name="internetClient" /><Capability Name="internetClientServer" /><Capability Name="privateNetworkClientServer" /><rescap:Capability Name="runFullTrust" /></Capabilities>
</Package>
"@
[IO.File]::WriteAllText((Join-Path $payload 'AppxManifest.xml'), $manifest, [Text.UTF8Encoding]::new($false))
$package = Join-Path $output "SpeshTV-$StoreVersion-x64.msix"
& $makeAppx pack /d $payload /p $package
if ($LASTEXITCODE) { throw 'MSIX packaging or manifest validation failed.' }
$metadata = [ordered]@{
    status = 'unsigned-submission-review-only'
    storeId = '9NWFFH7RTP8S'
    packageIdentity = 'SpeshCaster.SpeshTV'
    storeVersion = $StoreVersion
    sourceBuild = $inventory.version
    privacyUrl = 'https://privacy.oriemplx.cc/'
    website = 'https://apps.oriemplx.cc/'
    sha256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
    certificationPassed = $false
    publicationApproved = $false
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'submission-review.json') -Encoding UTF8
Write-Output "Unsigned Store review package: $package"
