<#
.SYNOPSIS
    Installs the Thai translation build (build/www) into the HOPE 01 game folder.

.DESCRIPTION
    Copies build/www/data.json, build/www/scripts/c3main.js and build/www/images/thai-font-*.png
    into the game's www folder. build/www/scripts/main.js is a local browser-test copy and is
    never installed.

    Before the first install the original data.json / c3main.js are saved to
    <project>/backup/original/ together with their SHA-256. If the game was updated since
    (hash differs from the build's source), the script refuses: re-run extract + build first.

    Independent of the cheat plugin (that one only adds a <script> to index.html).
#>
param(
    [string]$GameDir = "I:\SteamLibrary\steamapps\common\HOPE 01"
)

$ErrorActionPreference = "Stop"
$root   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$build  = Join-Path $root "build\www"
$backup = Join-Path $root "backup\original"
$www    = Join-Path $GameDir "www"

foreach ($f in "data.json", "scripts\c3main.js") {
    if (-not (Test-Path (Join-Path $build $f))) { throw "build\www\$f missing - run tools/build.html first" }
}

New-Item -ItemType Directory -Force (Join-Path $backup "scripts") | Out-Null
foreach ($f in "data.json", "scripts\c3main.js") {
    $game = Join-Path $www $f
    $saved = Join-Path $backup $f
    $gameHash = (Get-FileHash $game -Algorithm SHA256).Hash
    $builtHash = (Get-FileHash (Join-Path $build $f) -Algorithm SHA256).Hash
    if ($gameHash -eq $builtHash) { Write-Host "$f already installed"; continue }
    if (Test-Path $saved) {
        # The game file must be the original we built from (not changed by a game update).
        $savedHash = (Get-FileHash $saved -Algorithm SHA256).Hash
        if ($gameHash -ne $savedHash) {
            throw "$f in the game differs from backup\original (game updated?). Re-run extract.html + build.html, then delete backup\original and install again."
        }
    } else {
        Copy-Item $game $saved
        Write-Host "backup  -> $saved"
    }
    Copy-Item (Join-Path $build $f) $game -Force
    Write-Host "install -> $game"
}

$fonts = Get-ChildItem (Join-Path $build "images") -Filter "thai-font-*.png"
New-Item -ItemType Directory -Force (Join-Path $www "images") | Out-Null
Get-ChildItem (Join-Path $www "images") -Filter "thai-font-*.png" | Remove-Item
foreach ($p in $fonts) { Copy-Item $p.FullName (Join-Path $www "images") -Force }
Write-Host "fonts   -> $($fonts.Count) files"
Write-Host "done."
