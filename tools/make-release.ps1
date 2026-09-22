<#
.SYNOPSIS
    Makes the player download: release/HOPE01-Thai-v<version>/ and release/HOPE01-Thai-v<version>.zip.
.DESCRIPTION
    The package holds only this project's work (translations, the bitsy font, the build pages and
    the installer) - no game files. The installer builds the Thai files on the player's PC from
    their own game, so small game updates keep working. Version: VERSION.txt in the project root.
#>
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$version = (Get-Content (Join-Path $root "VERSION.txt") | Select-Object -First 1).Trim()
$name = "HOPE01-Thai-v$version"
$out = Join-Path $root "release\$name"
$mod = Join-Path $out "mod"
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $mod "tools"), (Join-Path $mod "installer"), (Join-Path $mod "translations"), (Join-Path $mod "fonts") | Out-Null

foreach ($f in "extract.html", "build.html", "lib.js") { Copy-Item (Join-Path $root "tools\$f") (Join-Path $mod "tools") }
Copy-Item (Join-Path $root "translations\th-*.csv") (Join-Path $mod "translations")
Copy-Item (Join-Path $root "fonts\Thai_nuttatulipa.bitsyfont") (Join-Path $mod "fonts")
Copy-Item (Join-Path $root "VERSION.txt") $mod
# PowerShell 5.1 reads BOM-less .ps1 files as ANSI: write them as UTF-8 with BOM (Thai messages).
$bom = New-Object System.Text.UTF8Encoding($true)
foreach ($f in Get-ChildItem (Join-Path $root "installer") -Filter "*.ps1") {
    [IO.File]::WriteAllText((Join-Path $mod "installer\$($f.Name)"), [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8), $bom)
}
$bat = { param($script) "@echo off`r`nchcp 65001 >nul`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0mod\installer\$script`" %*`r`necho.`r`npause`r`n" }
[IO.File]::WriteAllText((Join-Path $out "Install-Thai.bat"), (& $bat "install.ps1"), [Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $out "Uninstall-Thai.bat"), (& $bat "uninstall.ps1"), [Text.Encoding]::ASCII)
$readme = [IO.File]::ReadAllText((Join-Path $root "installer\README-TH.txt"), [Text.Encoding]::UTF8).Replace("{VERSION}", $version)
[IO.File]::WriteAllText((Join-Path $out "README-TH.txt"), $readme, $bom)

$zip = Join-Path $root "release\$name.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path $out -DestinationPath $zip
$size = [math]::Round((Get-Item $zip).Length / 1MB, 2)
Write-Host "release: $zip ($size MB)"
