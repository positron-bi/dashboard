[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$WebRoot = "C:\inetpub\wwwroot"
)

$ErrorActionPreference = "Stop"
$packagePath = (Resolve-Path -LiteralPath $PackageRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $packagePath "dashboard\index.html"))) {
    throw "Dashboard package is incomplete: $packagePath"
}

Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart | Out-Null
New-Item -ItemType Directory -Path $WebRoot -Force | Out-Null

& robocopy $packagePath $WebRoot /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XD ".git" ".github" "tools" /XF "LOCAL-PUBLISHING.md"
if ($LASTEXITCODE -gt 7) {
    throw "Copy to IIS web root failed. Robocopy exit code: $LASTEXITCODE"
}

Import-Module WebAdministration
Start-Service W3SVC
if (-not (Get-NetFirewallRule -DisplayName "Positron BI Dashboards (HTTP)" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Positron BI Dashboards (HTTP)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 -Profile Domain,Private | Out-Null
}

[PSCustomObject]@{
    DashboardUrl = "http://$env:COMPUTERNAME/dashboard/"
    IpUrl = "http://192.168.0.105/dashboard/"
    WebRoot = $WebRoot
}
