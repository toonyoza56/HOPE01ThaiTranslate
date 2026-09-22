# Like dialogue-test.ps1 but opens DialogueBoxChoices with the longest options and captures no-hover / hover on choice 2.
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
& "$s\cdp.ps1" -File "$s\choices.js"
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 1000, 440
$gr = [Drawing.Graphics]::FromImage($bmp)
$k = 0
foreach ($y in 1000, 402) {
    & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":900,"y":' + ($y - 6) + '}') | Out-Null
    Start-Sleep -Milliseconds 300
    & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":902,"y":' + $y + '}') | Out-Null
    Start-Sleep 1
    & "$s\cdp.ps1" -Shot "$out\ch_$k.png" | Out-Null
    $img = [Drawing.Image]::FromFile("$out\ch_$k.png")
    $gr.DrawImage($img, (New-Object Drawing.Rectangle 0, ($k * 220), 1000, 220), (New-Object Drawing.Rectangle 460, 300, 1000, 220), [Drawing.GraphicsUnit]::Pixel)
    $img.Dispose(); $k++
}
$bmp.Save("$out\$Name.png")
Stop-Process -Name "Hope 01" -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Remove-Item "$g\steam_appid.txt" -ErrorAction SilentlyContinue
"saved $Name.png"
