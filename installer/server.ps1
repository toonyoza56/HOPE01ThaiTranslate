# Minimal local HTTP server for the installer (TcpListener on 127.0.0.1: no admin rights / URL ACL
# needed, unlike HttpListener). Same routes as tools/serve.ps1:
#   GET  /<path>              file from the mod folder
#   GET  /game/<path>         file from the game's www folder
#   GET  /list/translations   JSON list of translations/*.csv
#   POST /work/<name>         body -> <mod>/work/<name>
#   POST /build/<path>        body -> <mod>/build/www/<path>
# Stops when <mod>/work/stop-server exists or after 15 minutes.
param([Parameter(Mandatory)] [string]$Root, [Parameter(Mandatory)] [string]$GameWww, [Parameter(Mandatory)] [int]$Port)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path $Root).Path; $GameWww = (Resolve-Path $GameWww).Path
$work = Join-Path $Root "work"; $buildRoot = Join-Path $Root "build\www"
New-Item -ItemType Directory -Force $work, $buildRoot | Out-Null
$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".json" = "application/json"; ".csv" = "text/csv; charset=utf-8";
            ".png" = "image/png"; ".webp" = "image/webp"; ".txt" = "text/plain; charset=utf-8" }
$listener = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
$listener.Start()
$deadline = (Get-Date).AddMinutes(15)

function Send($stream, [int]$code, [byte[]]$body, [string]$type) {
    $status = @{ 200 = "OK"; 204 = "No Content"; 404 = "Not Found"; 500 = "Error" }[$code]
    $head = "HTTP/1.1 $code $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $h = [Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($h, 0, $h.Length)
    for ($o = 0; $o -lt $body.Length; $o += 65536) { $stream.Write($body, $o, [Math]::Min(65536, $body.Length - $o)) }
    $stream.Flush()
}

while ((Get-Date) -lt $deadline -and -not (Test-Path (Join-Path $work "stop-server"))) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 20; continue }
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 10000
        $stream = $client.GetStream()
        # headers
        $buf = New-Object System.IO.MemoryStream
        $one = New-Object byte[] 1
        while ($true) {
            if ($stream.Read($one, 0, 1) -le 0) { break }
            $buf.WriteByte($one[0])
            $n = $buf.Length
            if ($n -ge 4) { $a = $buf.GetBuffer(); if ($a[$n-4] -eq 13 -and $a[$n-3] -eq 10 -and $a[$n-2] -eq 13 -and $a[$n-1] -eq 10) { break } }
        }
        $headText = [Text.Encoding]::ASCII.GetString($buf.ToArray())
        $lines = $headText -split "`r`n"
        $method, $target = $lines[0].Split(" ")[0, 1]
        $len = 0
        foreach ($l in $lines) { if ($l -match '^Content-Length:\s*(\d+)') { $len = [int]$Matches[1] } }
        $body = New-Object byte[] $len
        $got = 0
        while ($got -lt $len) { $r = $stream.Read($body, $got, $len - $got); if ($r -le 0) { break }; $got += $r }
        $rel = [Uri]::UnescapeDataString(($target -split "\?")[0].TrimStart("/"))

        if ($method -eq "POST" -and ($rel.StartsWith("work/") -or $rel.StartsWith("build/"))) {
            if ($rel.StartsWith("work/")) { $dest = Join-Path $work ([IO.Path]::GetFileName($rel)) }
            else {
                $dest = [IO.Path]::GetFullPath((Join-Path $buildRoot $rel.Substring(6)))
                if (-not $dest.StartsWith($buildRoot)) { throw "bad path" }
            }
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            [IO.File]::WriteAllBytes($dest, $body)
            Send $stream 204 @() "text/plain"
        } elseif ($rel -eq "list/translations") {
            $names = @(Get-ChildItem (Join-Path $Root "translations") -Filter "*.csv" | Sort-Object Name | ForEach-Object { $_.Name })
            Send $stream 200 ([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $names -Compress))) "application/json"
        } else {
            if ($rel.StartsWith("game/")) { $base = $GameWww; $rel = $rel.Substring(5) } else { $base = $Root }
            $path = [IO.Path]::GetFullPath((Join-Path $base $rel))
            if ($path.StartsWith($base) -and (Test-Path $path -PathType Leaf)) {
                $ext = [IO.Path]::GetExtension($path).ToLower()
                Send $stream 200 ([IO.File]::ReadAllBytes($path)) ($(if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" }))
            } else { Send $stream 404 @() "text/plain" }
        }
    } catch {
        Add-Content -Path (Join-Path $work "server-errors.txt") -Value ("$rel : " + $_.Exception.ToString())
        try { Send $stream 500 @() "text/plain" } catch {}
    } finally {
        # graceful close: an abrupt Close() on a large response resets the connection (seen with data.json)
        try { $client.Client.Shutdown([Net.Sockets.SocketShutdown]::Send); $client.Client.ReceiveTimeout = 2000; $tmp = New-Object byte[] 1024; while ($client.Client.Receive($tmp) -gt 0) {} } catch {}
        $client.Close()
    }
}
$listener.Stop()
