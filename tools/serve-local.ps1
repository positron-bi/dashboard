[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards",
    [int]$Port = 8080,
    [string]$BindAddress = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $LocalRoot)) {
    throw "Local dashboard folder does not exist: $LocalRoot"
}

$rootPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $LocalRoot).Path)
if (-not $rootPath.EndsWith([IO.Path]::DirectorySeparatorChar)) {
    $rootPath += [IO.Path]::DirectorySeparatorChar
}

$mimeTypes = @{
    ".css" = "text/css; charset=utf-8"; ".gif" = "image/gif"; ".html" = "text/html; charset=utf-8"
    ".ico" = "image/x-icon"; ".jpeg" = "image/jpeg"; ".jpg" = "image/jpeg"; ".js" = "text/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"; ".png" = "image/png"; ".svg" = "image/svg+xml"; ".txt" = "text/plain; charset=utf-8"
    ".webp" = "image/webp"; ".xml" = "application/xml; charset=utf-8"
}

$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://${BindAddress}:$Port/")
$listener.Start()
Write-Host "Local dashboards: http://${BindAddress}:$Port/dashboard/"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $requestedPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/')).Replace('/', [IO.Path]::DirectorySeparatorChar)
            $filePath = [IO.Path]::GetFullPath((Join-Path $rootPath $requestedPath))
            if (-not $filePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid path" }
            if (Test-Path -LiteralPath $filePath -PathType Container) { $filePath = Join-Path $filePath "index.html" }
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                $context.Response.StatusCode = 404
                $bytes = [Text.Encoding]::UTF8.GetBytes("Not found")
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                continue
            }
            $extension = [IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $context.Response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
            $context.Response.ContentLength64 = (Get-Item -LiteralPath $filePath).Length
            if ($context.Request.HttpMethod -ne "HEAD") {
                $stream = [IO.File]::OpenRead($filePath)
                try { $stream.CopyTo($context.Response.OutputStream) } finally { $stream.Dispose() }
            }
        }
        catch { $context.Response.StatusCode = 400 }
        finally { $context.Response.Close() }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
