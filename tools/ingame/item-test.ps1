# Installs build/www, starts the real game with CDP, loads the save, opens the inventory (B) and
# hovers 4 inventory slots; saves the item panels side by side to work/ingame/<Name>.png.
# Slot coordinates are for a 1920x1080 window and the user's current inventory.
param([string]$Name)
$s = $PSScriptRoot
$out = Join-Path $PSScriptRoot "..\..\work\ingame"; New-Item -ItemType Directory -Force $out | Out-Null
$g = "I:\SteamLibrary\steamapps\common\HOPE 01"
powershell -ExecutionPolicy Bypass -File I:\HOPE01-ThaiMod\tools\install.ps1 | Out-Null
Set-Content -Path "$g\steam_appid.txt" -Value "4562940" -Encoding ascii -NoNewline
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = "--remote-debugging-port=9222"
Start-Process -FilePath "$g\Hope 01.exe" -WorkingDirectory $g
Start-Sleep 12
foreach ($t in "mouseMoved", "mousePressed", "mouseReleased") { & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"' + $t + '","x":330,"y":665,"button":"left","clickCount":1}') | Out-Null; Start-Sleep -Milliseconds 120 }
Start-Sleep 6
foreach ($t in "keyDown", "keyUp") { & "$s\cdp.ps1" -Method Input.dispatchKeyEvent -Params ('{"type":"' + $t + '","key":"b","code":"KeyB","windowsVirtualKeyCode":66}') | Out-Null; Start-Sleep -Milliseconds 100 }
Start-Sleep 2
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 1280, 540
$gr = [Drawing.Graphics]::FromImage($bmp)
$k = 0
foreach ($pt in @(@(600, 792), @(795, 792), @(1030, 792), @(1075, 840))) {
    & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":' + ($pt[0] - 4) + ',"y":' + $pt[1] + '}') | Out-Null
    Start-Sleep -Milliseconds 200
    & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":' + $pt[0] + ',"y":' + $pt[1] + '}') | Out-Null
    Start-Sleep 1
    & "$s\cdp.ps1" -Shot "$out\item_$k.png" | Out-Null
    $img = [Drawing.Image]::FromFile("$out\item_$k.png")
    $gr.DrawImage($img, (New-Object Drawing.Rectangle ($k * 320), 0, 320, 540), (New-Object Drawing.Rectangle 1280, 270, 640, 1080), [Drawing.GraphicsUnit]::Pixel)
    $img.Dispose(); $k++
}
$bmp.Save("$out\$Name.png")
Stop-Process -Name "Hope 01" -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Remove-Item "$g\steam_appid.txt" -ErrorAction SilentlyContinue
"saved $Name.png"
