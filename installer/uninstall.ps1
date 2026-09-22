# HOPE 01 Thai translation - uninstaller: puts the original game files back (only if they are still
# the ones this mod installed; after a Steam update there is nothing to undo) and removes the backup.
param([string]$GameDir)
. (Join-Path $PSScriptRoot "common.ps1")
try {
    Say "=== HOPE 01 แปลไทย : ถอนการติดตั้ง ===" "HOPE 01 Thai translation - uninstall" "Cyan"
    $game = Find-GameDir $GameDir
    Say "เกม: $game" ""
    Assert-GameClosed
    $wasInstalled = Test-ThaiInstalled (Join-Path $game "www")
    [void](Restore-Originals $game)
    Remove-Item (Get-BackupDir $game) -Recurse -Force -ErrorAction SilentlyContinue
    if ($wasInstalled) { Say "ถอนภาษาไทยแล้ว เกมกลับเป็นภาษาอังกฤษ" "Removed. The game is back to English." "Green" }
    else { Say "ไม่พบภาษาไทยในเกม (ไม่มีอะไรต้องถอน)" "The Thai translation is not installed." "Green" }
    Say "เซฟเกมยังใช้ต่อได้ตามปกติ" "Your saves keep working." ""
} catch {
    if ($_.Exception.Message -notlike "STOP:*") { Say "เกิดข้อผิดพลาด: $($_.Exception.Message)" "Unexpected error." "Red" }
    exit 1
}
