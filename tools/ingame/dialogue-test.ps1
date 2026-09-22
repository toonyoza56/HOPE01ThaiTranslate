# Installs build/www, starts the real game with CDP (port 9222), loads the save (Load button),
# shows test dialogues via runtime.AU("DialogueShow"), saves a strip to work/ingame/<Name>.png, closes the game.
# steam_appid.txt is created for the run and removed again.
param([string]$Name)
# Install the current build, start the game with CDP, load the save, show test dialogues, save a strip.
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
Add-Type -AssemblyName System.Drawing
$picks = "CYCLER", "ICK ", "BCS ", " 14 ", "longest"
$bmp = New-Object Drawing.Bitmap 960, (200 * $picks.Count)
$gr = [Drawing.Graphics]::FromImage($bmp)
$k = 0
foreach ($p in $picks) {
    & "$s\cdp.ps1" -Expr "self.PICK='$p'" | Out-Null
    & "$s\cdp.ps1" -File "$s\dialogue.js" -Shot "$out\t_$k.png" | Out-Null
    $img = [Drawing.Image]::FromFile("$out\t_$k.png")
    $gr.DrawImage($img, (New-Object Drawing.Rectangle 0, ($k * 200), 960, 200), (New-Object Drawing.Rectangle 480, 140, 960, 200), [Drawing.GraphicsUnit]::Pixel)
    $img.Dispose(); $k++
}
$bmp.Save("$out\$Name.png")
Stop-Process -Name "Hope 01" -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Remove-Item "$g\steam_appid.txt" -ErrorAction SilentlyContinue
"saved $Name.png"

