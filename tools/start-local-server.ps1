[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards",
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$serverScript = Join-Path $PSScriptRoot "serve-local.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$serverScript`" -LocalRoot `"$LocalRoot`" -Port $Port"
Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden
Write-Host "Local server started: http://127.0.0.1:$Port/dashboard/"
