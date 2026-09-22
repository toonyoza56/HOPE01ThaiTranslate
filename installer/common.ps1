# Shared helpers for the release installer (install.ps1 / uninstall.ps1).
$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$SteamAppId = 4562940
$ThaiMarker = "thai-font-"          # present in data.json only when the Thai build is installed

function Say([string]$th, [string]$en, [string]$color = "Gray") {
    if (-not $color) { $color = "Gray" }
    Write-Host $th -ForegroundColor $color
    if ($en) { Write-Host "  $en" -ForegroundColor DarkGray }
}

function Fail([string]$th, [string]$en) {
    Say $th $en "Red"
    throw "STOP: $en"
}

# Game folder: -GameDir, else Steam libraries (registry + libraryfolders.vdf), else ask.
function Find-GameDir([string]$GameDir) {
    $ok = { param($d) $d -and (Test-Path (Join-Path $d "Hope 01.exe")) -and (Test-Path (Join-Path $d "www\data.json")) }
    if (& $ok $GameDir) { return (Resolve-Path $GameDir).Path }
    $steamRoots = @()
    foreach ($key in "HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam") {
        try {
            $p = Get-ItemProperty $key -ErrorAction Stop
            foreach ($v in $p.SteamPath, $p.InstallPath) { if ($v) { $steamRoots += ($v -replace "/", "\") } }
        } catch {}
    }
    $libs = @()
    foreach ($root in ($steamRoots | Select-Object -Unique)) {
        $libs += $root
        $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace "\\\\", "\") }
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $d = Join-Path $lib "steamapps\common\HOPE 01"
        if (& $ok $d) { return (Resolve-Path $d).Path }
    }
    Say "หาโฟลเดอร์เกม HOPE 01 ไม่เจอ" "HOPE 01 folder not found."
    $d = Read-Host "วางที่อยู่โฟลเดอร์เกม (ที่มีไฟล์ Hope 01.exe) / paste the game folder"
    $d = $d.Trim('"', ' ')
    if (& $ok $d) { return (Resolve-Path $d).Path }
    Fail "โฟลเดอร์นี้ไม่ใช่โฟลเดอร์เกม HOPE 01" "Not a HOPE 01 folder: $d"
}

function Test-ThaiInstalled([string]$www) {
    return [bool](Select-String -Path (Join-Path $www "data.json") -Pattern $ThaiMarker -SimpleMatch -Quiet)
}

function Hash([string]$path) { (Get-FileHash $path -Algorithm SHA256).Hash }

function Assert-GameClosed {
    if (Get-Process -Name "Hope 01" -ErrorAction SilentlyContinue) {
        Fail "กรุณาปิดเกม HOPE 01 ก่อน แล้วรันใหม่" "Close HOPE 01 first, then run this again."
    }
}

# Backup of the original game files lives in the game folder, so uninstall works from any copy.
function Get-BackupDir([string]$gameDir) { Join-Path $gameDir "thai-mod-backup" }

# Puts the original data.json / c3main.js back if the Thai build is installed (checked by hash, so a
# Steam update in between is never overwritten with old files). Returns $true when originals are in place.
function Restore-Originals([string]$gameDir) {
    $www = Join-Path $gameDir "www"
    $bak = Get-BackupDir $gameDir
    $stateFile = Join-Path $bak "installed.json"
    if (Test-ThaiInstalled $www) {
        if (-not (Test-Path $stateFile)) {
            Fail "ไฟล์เกมถูกแก้ไว้แต่ไม่มีข้อมูลสำรอง: ใช้ Steam > Properties > Installed Files > Verify integrity แล้วรันใหม่" `
                 "Thai files found but no backup. Use Steam 'Verify integrity of game files', then run again."
        }
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        if ((Hash (Join-Path $www "data.json")) -ne $state.installedData -or (Hash (Join-Path $www "scripts\c3main.js")) -ne $state.installedC3main) {
            Fail "ไฟล์เกมไม่ตรงกับที่ติดตั้งไว้: ใช้ Steam > Verify integrity แล้วรันใหม่" `
                 "Game files changed since install. Use Steam 'Verify integrity of game files', then run again."
        }
        Copy-Item (Join-Path $bak "data.json") (Join-Path $www "data.json") -Force
        Copy-Item (Join-Path $bak "c3main.js") (Join-Path $www "scripts\c3main.js") -Force
    }
    Get-ChildItem (Join-Path $www "images") -Filter "$ThaiMarker*.png" -ErrorAction SilentlyContinue | Remove-Item
    return -not (Test-ThaiInstalled $www)
}
