<#
.SYNOPSIS
    Restores the original English data.json / c3main.js and removes the Thai font sheets.
#>
param(
    [string]$GameDir = "I:\SteamLibrary\steamapps\common\HOPE 01"
)

$ErrorActionPreference = "Stop"
$root   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backup = Join-Path $root "backup\original"
$www    = Join-Path $GameDir "www"

foreach ($f in "data.json", "scripts\c3main.js") {
    $saved = Join-Path $backup $f
    if (Test-Path $saved) {
        Copy-Item $saved (Join-Path $www $f) -Force
        Write-Host "restored $f"
    } else {
        Write-Host "no backup for $f (not installed, or use Steam 'Verify integrity')"
    }
}
Get-ChildItem (Join-Path $www "images") -Filter "thai-font-*.png" -ErrorAction SilentlyContinue | Remove-Item
Write-Host "removed Thai font sheets"
Write-Host "done."
