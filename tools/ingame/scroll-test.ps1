# Installs build/www, loads the save, opens the inventory, hovers the slot at -X/-Y (default: the
# quest note in the user's inventory) and captures the item panel: as shown, after ArrowDown x3,
# after mouse wheel down, after ArrowUp x9 -> work/ingame/<Name>.png
param([string]$Name, [int]$X = 690, [int]$Y = 840)
$s = $PSScriptRoot
$out = Join-Path $PSScriptRoot "..\..\work\ingame"; New-Item -ItemType Directory -Force $out | Out-Null
$g = "I:\SteamLibrary\steamapps\common\HOPE 01"
powershell -ExecutionPolicy Bypass -File I:\HOPE01-ThaiMod\tools\install.ps1 | Out-Null
Set-Content -Path "$g\steam_appid.txt" -Value "4562940" -Encoding ascii -NoNewline
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = "--remote-debugging-port=9222"
Start-Process -FilePath "$g\Hope 01.exe" -WorkingDirectory $g
Start-Sleep 12
function Key($key, $code, $vk) { foreach ($t in "keyDown", "keyUp") { & "$s\cdp.ps1" -Method Input.dispatchKeyEvent -Params ('{"type":"' + $t + '","key":"' + $key + '","code":"' + $code + '","windowsVirtualKeyCode":' + $vk + '}') | Out-Null; Start-Sleep -Milliseconds 80 } }
foreach ($t in "mouseMoved", "mousePressed", "mouseReleased") { & "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"' + $t + '","x":330,"y":665,"button":"left","clickCount":1}') | Out-Null; Start-Sleep -Milliseconds 120 }
Start-Sleep 6
Key "b" "KeyB" 66
Start-Sleep 2
& "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":' + ($X - 4) + ',"y":' + $Y + '}') | Out-Null
Start-Sleep -Milliseconds 200
& "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params ('{"type":"mouseMoved","x":' + $X + ',"y":' + $Y + '}') | Out-Null
Start-Sleep 1
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 1280, 540
$gr = [Drawing.Graphics]::FromImage($bmp)
function Shot($k) {
    & "$s\cdp.ps1" -Shot "$out\scroll_$k.png" | Out-Null
    $img = [Drawing.Image]::FromFile("$out\scroll_$k.png")
    $gr.DrawImage($img, (New-Object Drawing.Rectangle ($k * 320), 0, 320, 540), (New-Object Drawing.Rectangle 1280, 270, 640, 1080), [Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
}
Shot 0
1..3 | ForEach-Object { Key "ArrowDown" "ArrowDown" 40 }; Start-Sleep -Milliseconds 400; Shot 1
& "$s\cdp.ps1" -Method Input.dispatchMouseEvent -Params '{"type":"mouseWheel","x":1580,"y":600,"deltaX":0,"deltaY":120}' | Out-Null; Start-Sleep -Milliseconds 400; Shot 2
1..9 | ForEach-Object { Key "ArrowUp" "ArrowUp" 38 }; Start-Sleep -Milliseconds 400; Shot 3
& "$s\cdp.ps1" -Expr "(()=>{const by={}; Object.values(HopeCheat.runtime.QH).forEach(c=>by[c.name]=c); const i=by['item_stext_description'].BV()[0]; return 'engine text height '+i.b1+' box '+i.height; })()"
$bmp.Save("$out\$Name.png")
Stop-Process -Name "Hope 01" -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Remove-Item -LiteralPath "$g\steam_appid.txt" -ErrorAction SilentlyContinue
"saved $Name.png"
