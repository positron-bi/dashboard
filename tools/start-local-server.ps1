[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards",
    [int]$Port = 8080,
    [string]$BindAddress = "0.0.0.0"
)

$ErrorActionPreference = "Stop"
$serverScript = Join-Path $PSScriptRoot "serve-local.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$serverScript`" -LocalRoot `"$LocalRoot`" -Port $Port -BindAddress $BindAddress"
Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden
$displayAddress = if ($BindAddress -eq "0.0.0.0") { "127.0.0.1" } else { $BindAddress }
Write-Host "Local server started: http://${displayAddress}:$Port/dashboard/"
