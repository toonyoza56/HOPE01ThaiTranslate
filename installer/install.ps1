# HOPE 01 Thai translation - installer.
# Builds the Thai files on this PC from the installed game (so small game updates keep working),
# using Microsoft Edge in headless mode to run tools/extract.html and tools/build.html, then copies
# data.json / scripts/c3main.js / images/thai-font-*.png into the game. Originals are backed up in
# <game>\thai-mod-backup (uninstall.ps1 puts them back).
param([string]$GameDir)
. (Join-Path $PSScriptRoot "common.ps1")
$mod = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$work = Join-Path $mod "work"
$logFile = Join-Path $mod "install-log.txt"
Start-Transcript -Path $logFile -Force | Out-Null
$server = $null; $edgeProfile = $null
try {
    $version = (Get-Content (Join-Path $mod "VERSION.txt") -ErrorAction SilentlyContinue | Select-Object -First 1)
    Say "=== HOPE 01 แปลไทย $version : ติดตั้ง ===" "HOPE 01 Thai translation $version - install" "Cyan"

    $game = Find-GameDir $GameDir
    $www = Join-Path $game "www"
    Say "เกม: $game" ""
    Assert-GameClosed

    # 1) originals in place (a reinstall / upgrade restores the backup first)
    [void](Restore-Originals $game)
    $bak = Get-BackupDir $game
    New-Item -ItemType Directory -Force $bak | Out-Null
    Copy-Item (Join-Path $www "data.json") (Join-Path $bak "data.json") -Force
    Copy-Item (Join-Path $www "scripts\c3main.js") (Join-Path $bak "c3main.js") -Force
    Say "สำรองไฟล์เดิมไว้ที่ $bak" "Original files backed up."

    # 2) build with headless Edge
    $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $edge) {
        try { $edge = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" -ErrorAction Stop)."(default)" } catch {}
    }
    if (-not $edge -or -not (Test-Path $edge)) { Fail "ไม่พบ Microsoft Edge (ใช้สร้างไฟล์ภาษาไทย)" "Microsoft Edge not found (needed to build the Thai files)." }

    New-Item -ItemType Directory -Force $work | Out-Null
    Remove-Item (Join-Path $work "*") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $mod "build") -Recurse -Force -ErrorAction SilentlyContinue
    $probe = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0); $probe.Start(); $port = $probe.LocalEndpoint.Port; $probe.Stop()
    $server = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSScriptRoot\server.ps1`"", "-Root", "`"$mod`"", "-GameWww", "`"$www`"", "-Port", $port)
    $edgeProfile = Join-Path $env:TEMP ("hope01-thai-" + [guid]::NewGuid().ToString("N"))

    function Run-Page([string]$page, [string]$doneFile, [string]$what) {
        Say "กำลัง$what ..." ""
        $done = Join-Path $work $doneFile
        $p = Start-Process $edge -PassThru -ArgumentList @("--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--user-data-dir=`"$edgeProfile`"", "http://127.0.0.1:$port/tools/$page#auto")
        $t0 = Get-Date
        while (-not (Test-Path $done)) {
            if (((Get-Date) - $t0).TotalSeconds -gt 300) { Fail "หมดเวลา ($what)" "Timed out: $page" }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 300
        Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*$edgeProfile*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        $text = [IO.File]::ReadAllText($done, [Text.Encoding]::UTF8)
        if (-not $text.StartsWith("OK")) { Write-Host $text; Fail "$what ไม่สำเร็จ (ดูรายละเอียดใน install-log.txt)" "$page failed." }
        return $text
    }
    [void](Run-Page "extract.html" "extract-done.txt" "อ่านข้อความจากเกม")
    $buildLog = Run-Page "build.html" "build-done.txt" "สร้างไฟล์ภาษาไทย (ประมาณ 1 นาที)"

    # 3) the runtime hooks must be in place, else old saves / items would break -> do not install
    foreach ($critical in "SpriteFont save/load code not found", "instance variable save/load code not found") {
        if ($buildLog.Contains($critical)) {
            Fail "เกมเวอร์ชันนี้ใหม่เกินกว่าที่ mod รองรับ: รอ mod เวอร์ชันใหม่ (ไม่ได้แก้ไฟล์เกม)" "Unsupported game version ($critical). Nothing was changed."
        }
    }

    # 4) install
    $build = Join-Path $mod "build\www"
    Copy-Item (Join-Path $build "data.json") (Join-Path $www "data.json") -Force
    Copy-Item (Join-Path $build "scripts\c3main.js") (Join-Path $www "scripts\c3main.js") -Force
    $fonts = Get-ChildItem (Join-Path $build "images") -Filter "$ThaiMarker*.png"
    foreach ($f in $fonts) { Copy-Item $f.FullName (Join-Path $www "images") -Force }
    @{ version = $version; installed = (Get-Date).ToString("s")
       installedData = (Hash (Join-Path $www "data.json")); installedC3main = (Hash (Join-Path $www "scripts\c3main.js"))
       originalData = (Hash (Join-Path $bak "data.json")); originalC3main = (Hash (Join-Path $bak "c3main.js")) } |
        ConvertTo-Json | Set-Content (Join-Path $bak "installed.json") -Encoding UTF8

    $applied = ($buildLog -split "`n" | Where-Object { $_ -match "^applied " }) -join ""
    Say "ติดตั้งเสร็จแล้ว เปิดเกมผ่าน Steam ได้เลย" "Done. Start the game from Steam." "Green"
    Say "($applied, ภาพฟอนต์ $($fonts.Count) ไฟล์)" ""
    if ($applied -match "\((\d+) skipped") { if ([int]$Matches[1] -gt 0) { Say "เกมมีข้อความที่เปลี่ยนไป $($Matches[1]) จุด ส่วนนั้นจะยังเป็นภาษาอังกฤษ" "$($Matches[1]) texts changed in this game version stay English." "Yellow" } }
} catch {
    if ($_.Exception.Message -notlike "STOP:*") { Say "เกิดข้อผิดพลาด: $($_.Exception.Message)" "Unexpected error - see install-log.txt" "Red" }
    $exitCode = 1
} finally {
    if ($work -and (Test-Path $work)) { New-Item -ItemType File -Force (Join-Path $work "stop-server") | Out-Null }
    if ($server) { Start-Sleep -Milliseconds 500; Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    if ($edgeProfile -and (Test-Path $edgeProfile)) { Start-Sleep -Milliseconds 500; Remove-Item $edgeProfile -Recurse -Force -ErrorAction SilentlyContinue }
    Stop-Transcript | Out-Null
}
exit $exitCode
