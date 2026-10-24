[CmdletBinding()]
param(
    [string]$PackageRoot,
    [string]$WebRoot = "C:\inetpub\PositronBI-Dashboard",
    [string]$SiteName = "Positron BI Dashboard",
    [string]$HostName = "dashboard.parsgrp.com"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = Split-Path -Parent $PSScriptRoot
}

$packagePath = (Resolve-Path -LiteralPath $PackageRoot).Path
$portalPath = Join-Path $packagePath "dashboard\index.html"
if (-not (Test-Path -LiteralPath $portalPath)) {
    throw "Dashboard package was not found at: $packagePath"
}

Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication -All -NoRestart | Out-Null
Import-Module WebAdministration

New-Item -ItemType Directory -Path $WebRoot -Force | Out-Null

$robocopyArguments = @(
    $packagePath,
    $WebRoot,
    "/E",
    "/XD", ".git", ".github", "tools",
    "/XF", "LOCAL-PUBLISHING.md",
    "/COPY:DAT",
    "/DCOPY:DAT",
    "/R:2",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS"
)
& robocopy @robocopyArguments | Out-Host
if ($LASTEXITCODE -gt 7) {
    throw "Copying dashboard files failed (robocopy exit code: $LASTEXITCODE)."
}

if (Test-Path "IIS:\Sites\$SiteName") {
    Remove-Website -Name $SiteName
}

New-Website -Name $SiteName -PhysicalPath $WebRoot -Port 80 -HostHeader $HostName | Out-Null
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value $false
Set-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value $true

if (-not (Get-NetFirewallRule -DisplayName "Positron BI Dashboard (HTTP)" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Positron BI Dashboard (HTTP)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 -Profile Domain,Private | Out-Null
}

Start-Service W3SVC

[pscustomobject]@{
    SiteName = $SiteName
    InternalAddress = "http://$HostName/dashboard/"
    ServerAddress = "http://$env:COMPUTERNAME/dashboard/"
    Authentication = "Windows Authentication"
    NextStep = "Create DNS dashboard.parsgrp.com -> this server, then publish HTTPS 443 through the edge firewall."
}
