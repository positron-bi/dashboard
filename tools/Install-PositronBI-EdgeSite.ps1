[CmdletBinding()]
param(
    [string]$PackageRoot,
    [string]$WebRoot = "C:\inetpub\PositronBI-Dashboard",
    [string]$SiteName = "Positron BI Dashboard",
    [string]$HostName = "dashboard.parsgrp.com",
    [ValidateRange(1, 65535)]
    [int]$Port = 80
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

New-Website -Name $SiteName -PhysicalPath $WebRoot -Port $Port -HostHeader $HostName | Out-Null
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" -Location $SiteName -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value $true
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" -Location $SiteName -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value $false

$firewallRuleName = "Positron BI Dashboard (TCP $Port)"
if (-not (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Domain,Private | Out-Null
}

Start-Service W3SVC

$siteBaseUrl = if ($Port -eq 80) { "http://$HostName" } else { "http://${HostName}:$Port" }

[pscustomobject]@{
    SiteName = $SiteName
    InternalAddress = "$siteBaseUrl/dashboard/"
    Authentication = "Anonymous"
    NextStep = "Publish TCP $Port through the edge firewall for external access, or use a HTTPS reverse proxy on 443."
}
