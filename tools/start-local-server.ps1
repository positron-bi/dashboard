[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards",
    [int]$Port = 8080,
    [string]$BindAddress = "127.0.0.1"
)

$ErrorActionPreference = "Stop"
$serverScript = Join-Path $PSScriptRoot "serve-local.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$serverScript`" -LocalRoot `"$LocalRoot`" -Port $Port -BindAddress $BindAddress"
Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden
Write-Host "Local server started: http://${BindAddress}:$Port/dashboard/"
