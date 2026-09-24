param([int]$Port = 3000)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$mime = @{
    '.html'='text/html; charset=utf-8'
    '.js'  ='application/javascript; charset=utf-8'
    '.css' ='text/css; charset=utf-8'
    '.json'='application/json; charset=utf-8'
    '.svg' ='image/svg+xml'
    '.png' ='image/png'
    '.jpg' ='image/jpeg'
    '.jpeg'='image/jpeg'
    '.gif' ='image/gif'
    '.ico' ='image/x-icon'
    '.wasm'='application/wasm'
    '.data'='application/octet-stream'
    '.woff'='font/woff'
    '.woff2'='font/woff2'
}

$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)

# Auto find available port via raw socket
while ($Port -lt 65535) {
    try {
        $sock = [System.Net.Sockets.Socket]::new([System.Net.Sockets.AddressFamily]::InterNetwork,
                                                  [System.Net.Sockets.SocketType]::Stream,
                                                  [System.Net.Sockets.ProtocolType]::Tcp)
        $sock.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, $Port))
        $sock.Listen(10)
        break
    } catch {
        $sock?.Close()
        $Port++
    }
}
if (-not $sock) { Write-Host "No free port."; exit 1 }

"$Port" | Set-Content -Path (Join-Path $root '.port') -Encoding ASCII

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Word Card - Local Server on :$Port" -ForegroundColor Cyan
Write-Host "  Keep this window open" -ForegroundColor Cyan
Write-Host "  Local:  http://localhost:$Port/index.html" -ForegroundColor Yellow
if ($localIP) {
    Write-Host "  Mobile: http://${localIP}:$Port/index.html" -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Send-Response($client, $statusCode, $reason, $contentType, $bytes) {
    try {
        $client.SendTimeout = 3000
        $header = "HTTP/1.1 $statusCode $reason`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
        $client.Send($headerBytes, 0, $headerBytes.Length, [System.Net.Sockets.SocketFlags]::None) | Out-Null
        if ($bytes.Length -gt 0) {
            $client.Send($bytes, 0, $bytes.Length, [System.Net.Sockets.SocketFlags]::None) | Out-Null
        }
    } catch {}
    try { $client.Shutdown([System.Net.Sockets.SocketShutdown]::Both); $client.Close() } catch {}
}

# Server loop
while ($true) {
    $client = $null
    try {
        $client = $sock.Accept()
        $client.ReceiveTimeout = 5000
        $buf = [byte[]]::new(8192)
        $read = $client.Receive($buf)
        if ($read -le 0) { $client.Close(); continue }
        $req = [Text.Encoding]::ASCII.GetString($buf, 0, $read)
        $lines = $req -split "`r`n"
        $first = $lines[0]
        if (-not $first) { $client.Close(); continue }
        $parts = $first -split ' '
        $path = $parts[1]
        if (-not $path) { $client.Close(); continue }

        if ($path -eq '/') { $path = '/index.html' }
        $reqPath = [System.Uri]::UnescapeDataString($path)
        $fullPath = Join-Path $root $reqPath.TrimStart('/')

        if (-not (Test-Path $fullPath -PathType Leaf)) {
            $bytes = [Text.Encoding]::UTF8.GetBytes("404 not found: $reqPath")
            Send-Response $client 404 'Not Found' 'text/plain; charset=utf-8' $bytes
            continue
        }

        $ext = [IO.Path]::GetExtension($fullPath).ToLower()
        $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $data = [IO.File]::ReadAllBytes($fullPath)
        Send-Response $client 200 'OK' $ct $data
    } catch {
        try { if ($client) { $client.Close() } } catch {}
    }
}
