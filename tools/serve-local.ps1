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

Set-Location -LiteralPath $LocalRoot
Write-Host "Local dashboards: http://$BindAddress`:$Port/dashboard/"
& python -m http.server $Port --bind $BindAddress
