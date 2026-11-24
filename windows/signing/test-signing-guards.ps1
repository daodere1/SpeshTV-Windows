param([string]$ExampleExecutable)
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'package-signed-release.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('speshtv-signing-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$count = 0
function Expect-Rejection([scriptblock]$Action, [string]$Message) {
    try { & $Action; throw 'Unexpected signing acceptance.' }
    catch { if ($_.Exception.Message -notlike "*$Message*") { throw } }
}
function New-Fixture([string]$Name, [string]$Entry = 'SpeshTV/SpeshTV.exe') {
    $work = Join-Path $root $Name
    New-Item -ItemType Directory -Path $work | Out-Null
    $zip = Join-Path $work 'SpeshTV-Windows-3.1.2-Portable.zip'
    $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $zipEntry = $archive.CreateEntry($Entry)
        $writer = [IO.StreamWriter]::new($zipEntry.Open())
        try { $writer.Write('Not executable code') } finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
    "$((Get-FileHash -LiteralPath $zip).Hash)  $([IO.Path]::GetFileName($zip))" |
        Set-Content -LiteralPath (Join-Path $work 'SHA256SUMS.txt') -Encoding ascii
    return $work
}
try {
    $badHash = New-Fixture 'hash'
    ('0' * 64 + '  SpeshTV-Windows-3.1.2-Portable.zip') | Set-Content (Join-Path $badHash 'SHA256SUMS.txt')
    Expect-Rejection { & $script -Phase Prepare -WorkDirectory $badHash -Tag v3.1.2 } 'checksum mismatch'
    $count++
    $badPath = New-Fixture 'path' '../../outside.exe'
    Expect-Rejection { & $script -Phase Prepare -WorkDirectory $badPath -Tag v3.1.2 } 'Unsafe archive path'
    $count++
    $badVersion = New-Fixture 'version'
    Expect-Rejection { & $script -Phase Prepare -WorkDirectory $badVersion -Tag v3.1.2 } 'version does not match'
    $count++
    foreach ($phase in @('Package','Finalize')) {
        Expect-Rejection { & $script -Phase $phase -WorkDirectory $badVersion -Tag v3.1.2 -ExpectedPublisher 'CN=SpeshTV' } 'trusted, timestamped signature'
        $count++
    }
    if ($ExampleExecutable) {
        $work = Join-Path $root 'positive'
        $fixture = Join-Path $work 'input/SpeshTV'
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        Copy-Item -LiteralPath $ExampleExecutable -Destination (Join-Path $fixture 'SpeshTV.exe')
        'Test license' | Set-Content (Join-Path $fixture 'LICENSE')
        $version = (Get-Item $ExampleExecutable).VersionInfo.FileVersion.Split('+')[0]
        $zip = Join-Path $work "SpeshTV-Windows-$version-Portable.zip"
        Compress-Archive -LiteralPath $fixture -DestinationPath $zip
        "$((Get-FileHash $zip).Hash)  $([IO.Path]::GetFileName($zip))" | Set-Content (Join-Path $work 'SHA256SUMS.txt')
        & $script -Phase Prepare -WorkDirectory $work -Tag "v$version"
        if (!(Test-Path (Join-Path $work 'payload/SpeshTV/LICENSE'))) { throw 'Valid payload was not prepared.' }
        $count++
    }
    Write-Output "$count signing guard checks passed."
} finally {
    # Only the unique, locally created test directory is removed.
    $resolved = [IO.Path]::GetFullPath($root)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('speshtv-signing-tests-')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
