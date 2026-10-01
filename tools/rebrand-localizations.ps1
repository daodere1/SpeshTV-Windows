#Requires -Version 7
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$count = 0
foreach ($file in Get-ChildItem (Join-Path $root 'lib/l10n') -Filter '*.arb') {
    $text = [IO.File]::ReadAllText($file.FullName)
    $data = $text | ConvertFrom-Json -AsHashtable
    foreach ($property in $data.GetEnumerator()) {
        if ($property.Key.StartsWith('@') -or $property.Value -isnot [string]) { continue }
        $value = $property.Value
        if ($value -notmatch 'Moonfin' -or $value -match 'https?://') { continue }
        # Donation and server-plugin references identify the actual upstream service.
        if ($property.Key -like '*SupportMoonfin*') {
            $replacement = 'Support upstream project'
        } elseif ($property.Key -eq 'savedThemesDescription') {
            $replacement = 'Themes downloaded from the server theme plugin. Deleting removes only this local copy.'
        } elseif ($property.Key -eq 'themeEditorSubtitle') {
            $replacement = 'Open the server theme editor in your browser'
        } else {
            $replacement = [regex]::Replace($value, 'Moonfin', 'SpeshTV', 'IgnoreCase')
        }
        $jsonValue = ConvertTo-Json -InputObject $replacement -Compress
        $pattern = '("' + [regex]::Escape($property.Key) + '"\s*:\s*)"(?:\\.|[^"\\])*"'
        $text = [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $match.Groups[1].Value + $jsonValue
        })
    }
    $null = $text | ConvertFrom-Json -AsHashtable
    if ($text -ne [IO.File]::ReadAllText($file.FullName)) {
        [IO.File]::WriteAllText($file.FullName, $text, [Text.UTF8Encoding]::new($false))
        $count++
    }
}
Write-Output "Updated $count localization files."
