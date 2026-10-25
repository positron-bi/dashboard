[CmdletBinding()]
param(
    [string]$PackageRoot,
    [string]$WebRoot = "C:\inetpub\PositronBI-Dashboard",
    [string]$SiteName = "Positron BI Dashboard",
    [ValidateRange(1, 65535)]
    [int]$Port = 9192
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = Split-Path -Parent $PSScriptRoot
}
$PackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path

foreach ($required in @("Global.asax", "web.config", "App_Code\DashboardAccess.cs", "access\index.aspx")) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $required))) {
        throw "The Active Directory access package is incomplete: $required"
    }
}

if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
    Install-WindowsFeature Web-Windows-Auth, Web-Asp-Net45 | Out-Null
}
else {
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WindowsAuthentication,IIS-ASPNET45 -All -NoRestart | Out-Null
}

Import-Module WebAdministration
if (-not (Test-Path "IIS:\Sites\$SiteName")) {
    throw "The IIS site '$SiteName' was not found. No other IIS site was changed."
}

$binding = Get-WebBinding -Name $SiteName | Where-Object { $_.protocol -eq "http" -and $_.bindingInformation -match ":${Port}:" }
if (-not $binding) {
    throw "The IIS site '$SiteName' does not have an HTTP binding on port $Port. No other IIS site was changed."
}

New-Item -ItemType Directory -Path $WebRoot -Force | Out-Null
& robocopy $PackageRoot $WebRoot /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XD ".git" ".github" "tools" /XF "LOCAL-PUBLISHING.md" "dashboard-access.json" /NFL /NDL /NJH /NJS | Out-Host
if ($LASTEXITCODE -gt 7) {
    throw "Copying the access package failed (robocopy exit code: $LASTEXITCODE)."
}

$dataFolder = Join-Path $WebRoot "App_Data"
New-Item -ItemType Directory -Path $dataFolder -Force | Out-Null
$accessFile = Join-Path $dataFolder "dashboard-access.json"
if (-not (Test-Path -LiteralPath $accessFile)) {
    Set-Content -LiteralPath $accessFile -Value '{"Administrators":[],"Grants":[]}' -Encoding UTF8
}
& icacls $dataFolder /grant "IIS_IUSRS:(OI)(CI)M" /T /C | Out-Null

# Only the dedicated 9192 dashboard site is changed. Port 9191 is never read or modified.
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" -Location $SiteName -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name enabled -Value $false
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" -Location $SiteName -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name enabled -Value $true
Restart-WebAppPool -Name ((Get-Item "IIS:\Sites\$SiteName").ApplicationPool)

[pscustomobject]@{
    SiteName = $SiteName
    Port = $Port
    Authentication = "Windows Authentication / Active Directory"
    AccessManagement = "http://bi-report.parsgrp.com:$Port/access/"
    Portal = "http://bi-report.parsgrp.com:$Port/dashboard/"
    Scope = "Only the dedicated IIS site on port $Port; port 9191 was not changed."
}
