param([string]$Expr, [string]$File, [string]$Shot, [string]$Method, [string]$Params = "{}")
$ErrorActionPreference = "Stop"
$page = (Invoke-RestMethod http://127.0.0.1:9222/json) | Where-Object { $_.type -eq "page" } | Select-Object -First 1
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(30)
$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
function Send($obj) {
    $json = $obj | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $ws.SendAsync([ArraySegment[byte]]$bytes, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
    $buf = New-Object byte[] 1048576
    while ($true) {
        $ms = New-Object IO.MemoryStream
        do {
            $r = $ws.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None).Result
            $ms.Write($buf, 0, $r.Count)
        } while (-not $r.EndOfMessage)
        $text = [Text.Encoding]::UTF8.GetString($ms.ToArray())
        $msg = $text | ConvertFrom-Json
        if ($msg.id -eq $obj.id) { return $msg }
    }
}
if ($File) { $Expr = [IO.File]::ReadAllText($File) }
if ($Expr) {
    $m = Send @{ id = 1; method = "Runtime.evaluate"; params = @{ expression = $Expr; awaitPromise = $true; returnByValue = $true } }
    if ($m.result.exceptionDetails) { "EXCEPTION: " + ($m.result.exceptionDetails | ConvertTo-Json -Depth 6 -Compress) }
    else { $v = $m.result.result.value; if ($v -is [string]) { $v } else { $v | ConvertTo-Json -Depth 8 } }
}
if ($Method) {
    $m = Send @{ id = 3; method = $Method; params = ($Params | ConvertFrom-Json) }
    $m | ConvertTo-Json -Depth 8 -Compress
}
if ($Shot) {
    $m = Send @{ id = 2; method = "Page.captureScreenshot"; params = @{ format = "png" } }
    [IO.File]::WriteAllBytes($Shot, [Convert]::FromBase64String($m.result.data))
    "saved $Shot"
}
$ws.Dispose()
