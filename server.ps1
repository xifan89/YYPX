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

# Auto find an available port
while ($Port -lt 65535) {
    try {
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://localhost:$Port/")
        $listener.Start()
        break
    } catch {
        $listener = $null
        $Port++
    }
}
if (-not $listener) {
    Write-Host "No free port found." -ForegroundColor Red
    pause
    exit 1
}

$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Word Card - Local Server on :$Port" -ForegroundColor Cyan
Write-Host "  Keep this window open" -ForegroundColor Cyan
Write-Host "  Local:  http://localhost:$Port/index.html" -ForegroundColor Yellow
if ($localIP) {
    Write-Host "  Mobile: http://${localIP}:$Port/index.html" -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $reqPath = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            if ($reqPath -eq '/') { $reqPath = '/index.html' }

            $fullPath = Join-Path $root $reqPath.TrimStart('/')
            if (-not (Test-Path $fullPath -PathType Leaf)) {
                $ctx.Response.StatusCode = 404
                $bytes = [Text.Encoding]::UTF8.GetBytes('not found')
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                $ctx.Response.Close()
                continue
            }

            $ext = [IO.Path]::GetExtension($fullPath).ToLower()
            $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $ctx.Response.ContentType = $ct
            $ctx.Response.ContentLength64 = (Get-Item $fullPath).Length
            $buf = [IO.File]::ReadAllBytes($fullPath)
            $ctx.Response.OutputStream.Write($buf, 0, $buf.Length)
            $ctx.Response.Close()
        } catch {
            try { $ctx.Response.Close() } catch {}
        }
    }
} finally {
    $listener.Stop()
}
