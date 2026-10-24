[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards",
    [int]$Port = 8080,
    [string]$BindAddress = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $LocalRoot)) { throw "Local dashboard folder does not exist: $LocalRoot" }

$rootPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $LocalRoot).Path)
if (-not $rootPath.EndsWith([IO.Path]::DirectorySeparatorChar)) { $rootPath += [IO.Path]::DirectorySeparatorChar }
$mimeTypes = @{ ".css"="text/css; charset=utf-8"; ".gif"="image/gif"; ".html"="text/html; charset=utf-8"; ".ico"="image/x-icon"; ".jpeg"="image/jpeg"; ".jpg"="image/jpeg"; ".js"="text/javascript; charset=utf-8"; ".json"="application/json; charset=utf-8"; ".png"="image/png"; ".svg"="image/svg+xml"; ".txt"="text/plain; charset=utf-8"; ".webp"="image/webp"; ".xml"="application/xml; charset=utf-8" }

function Send-Response {
    param($Stream, [int]$StatusCode, [string]$StatusText, [string]$ContentType, [byte[]]$Body, [bool]$SendBody)
    $header = "HTTP/1.1 $StatusCode $StatusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`n`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($SendBody -and $Body.Length) { $Stream.Write($Body, 0, $Body.Length) }
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($BindAddress), $Port)
$listener.Start()
Write-Host "Local dashboards: http://${BindAddress}:$Port/dashboard/"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $null
        $reader = $null
        try {
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 8192, $true)
            $requestLine = $reader.ReadLine()
            while ($reader.ReadLine()) { }
            if ($requestLine -notmatch '^(GET|HEAD)\s+([^\s]+)\s+HTTP/') {
                Send-Response $stream 400 "Bad Request" "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes("Bad request")) $true
                continue
            }

            $method = $matches[1]
            $requestPath = [Uri]::UnescapeDataString(($matches[2] -split '\?')[0])
            $relativePath = $requestPath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
            $filePath = [IO.Path]::GetFullPath((Join-Path $rootPath $relativePath))
            if (-not $filePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid path" }
            if (Test-Path -LiteralPath $filePath -PathType Container) { $filePath = Join-Path $filePath "index.html" }
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                Send-Response $stream 404 "Not Found" "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes("Not found")) ($method -eq "GET")
                continue
            }

            $extension = [IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
            $body = [IO.File]::ReadAllBytes($filePath)
            Send-Response $stream 200 "OK" $contentType $body ($method -eq "GET")
        }
        catch {
            if ($stream) { Send-Response $stream 400 "Bad Request" "text/plain; charset=utf-8" ([Text.Encoding]::UTF8.GetBytes("Bad request")) $true }
        }
        finally {
            if ($reader) { $reader.Dispose() }
            if ($stream) { $stream.Dispose() }
            $client.Dispose()
        }
    }
}
finally { $listener.Stop() }
