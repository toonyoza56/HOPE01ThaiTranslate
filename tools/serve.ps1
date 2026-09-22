# Local dev server for the Thai mod tools.
#   GET  /<path>        -> file from the project folder
#   GET  /game/<path>   -> file from the game's www folder (read-only)
#   GET  /play/<path>   -> patched build (build/www) over the original game, for testing in a browser
#   POST /work/<name>   -> writes the request body to <project>/work/<name>
#   POST /build/<path>  -> writes the request body to <project>/build/www/<path>
# http://localhost:8787/tools/extract.html
param(
    [int]$Port = 8787,
    [string]$GameWww = "I:\SteamLibrary\steamapps\common\HOPE 01\www"
)

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$work = Join-Path $root "work"
New-Item -ItemType Directory -Force $work | Out-Null
$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".json" = "application/json";
            ".css" = "text/css"; ".png" = "image/png"; ".webp" = "image/webp"; ".woff2" = "font/woff2"; ".csv" = "text/csv; charset=utf-8";
            ".wasm" = "application/wasm"; ".webm" = "audio/webm"; ".ogg" = "audio/ogg"; ".m4a" = "audio/mp4" }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "serving $root (+ /game -> $GameWww) on http://localhost:$Port/"

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
        $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart("/"))
        if ($req.HttpMethod -eq "POST" -and ($rel.StartsWith("work/") -or $rel.StartsWith("build/"))) {
            if ($rel.StartsWith("work/")) { $dest = Join-Path $work ([IO.Path]::GetFileName($rel)) }
            else {
                # build/<path> -> <project>/build/www/<path> (no escaping out of build/www)
                $buildRoot = Join-Path $root "build\www"
                $dest = [IO.Path]::GetFullPath((Join-Path $buildRoot $rel.Substring(6)))
                if (-not $dest.StartsWith([IO.Path]::GetFullPath($buildRoot))) { throw "bad path" }
            }
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            $fs = [IO.File]::Create($dest)
            $req.InputStream.CopyTo($fs)
            $fs.Close()
            $res.StatusCode = 204
        } elseif ($rel -eq "list/translations") {
            # JSON list of translations/*.csv (build merges them all)
            $names = @(Get-ChildItem (Join-Path $root "translations") -Filter "*.csv" | Sort-Object Name | ForEach-Object { $_.Name })
            $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $names -Compress))
            $res.ContentType = "application/json"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            if ($rel.StartsWith("game/")) { $base = (Resolve-Path $GameWww).Path; $rel = $rel.Substring(5) }
            elseif ($rel.StartsWith("play/")) {
                # Patched build over the original game: build/www first, then the game folder.
                $rel = $rel.Substring(5)
                $built = Join-Path $root "build\www"
                $base = if (Test-Path (Join-Path $built $rel) -PathType Leaf) { (Resolve-Path $built).Path } else { (Resolve-Path $GameWww).Path }
            }
            else { $base = $root }
            if ($rel -eq "") { $rel = "index.html" }
            $path = [IO.Path]::GetFullPath((Join-Path $base $rel))
            if ($path.StartsWith($base) -and (Test-Path $path -PathType Leaf)) {
                $bytes = [IO.File]::ReadAllBytes($path)
                $ext = [IO.Path]::GetExtension($path).ToLower()
                $res.ContentType = if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" }
                $res.Headers.Add("Cache-Control", "no-store")
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else { $res.StatusCode = 404 }
        }
    } catch { $res.StatusCode = 500 }
    $res.Close()
}
