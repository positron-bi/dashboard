[CmdletBinding()]
param(
    [string]$ServerShare = "\\BI-REPORT\PositronBI$",
    [string]$StatePath = (Join-Path $env:LOCALAPPDATA "PositronBI\server-sync-state.json")
)

$ErrorActionPreference = "Stop"
$publisher = Join-Path $PSScriptRoot "Publish-PositronBI-Server.ps1"
$desktop = Join-Path $env:USERPROFILE "Desktop"
$inventoryFolder = -join @([char]0x0627, [char]0x0646, [char]0x0628, [char]0x0627, [char]0x0631)

$sites = @(
    @{ Name = "dashboard"; Source = "C:\Dashboards\dashboard" },
    @{ Name = "aging-dashboard"; Source = (Join-Path $desktop "AR_Aging_Report\site") },
    @{ Name = "inventory-dashboard"; Source = (Join-Path (Join-Path $desktop $inventoryFolder) "site") },
    @{ Name = "Ledger-dashboard"; Source = (Join-Path $desktop "Ledger\site") },
    @{ Name = "reconciliation_dashboard"; Source = (Join-Path $desktop "run_reconciliation\site") },
    @{ Name = "atlas-dashboard"; Source = (Join-Path $env:USERPROFILE "Documents\Codex\2026-10-17\new-chat\outputs\atlas-web-dashboard") },
    @{ Name = "meta-dashboard"; Source = (Join-Path $env:USERPROFILE "Documents\Codex\2026-10-17\new-chat\outputs\meta-web-dashboard") },
    @{ Name = "vesta-dashboard"; Source = (Join-Path $desktop "vesta-dashboard-git") },
    @{ Name = "treasuryflow-dashboard"; Source = "X:\Accounting\report flow"; FilesOnly = @("index.html") }
)

function Get-SiteSignature {
    param([hashtable]$Site)
    $root = $Site.Source
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    $files = if ($Site.FilesOnly) {
        foreach ($file in $Site.FilesOnly) { Get-Item -LiteralPath (Join-Path $root $file) -ErrorAction SilentlyContinue }
    } else {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
            $_.FullName -notmatch '\\.git\\|\\.github\\|\\tools\\'
        }
    }
    if (@($files).Count -eq 0) { return $null }
    $parts = $files | Sort-Object FullName | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]::Join("`n", [string[]]$parts))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $ServerShare)) {
    throw "The internal publishing share is unavailable: $ServerShare"
}

$stateDirectory = Split-Path -Parent $StatePath
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$state = @{}
if (Test-Path -LiteralPath $StatePath) {
    $savedState = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    foreach ($property in $savedState.PSObject.Properties) {
        $state[$property.Name] = [string]$property.Value
    }
}

$published = @()
foreach ($site in $sites) {
    $signature = Get-SiteSignature -Site $site
    $siteName = [string]$site["Name"]
    if (-not $signature) { continue }
    $unchanged = $state.ContainsKey($siteName) -and [string]$state[$siteName] -eq [string]$signature
    Write-Verbose "Checked $siteName; changed=$(-not $unchanged)"
    if ($unchanged) { continue }

    $parameters = @{ Source = $site.Source; SiteName = $siteName; ServerShare = $ServerShare }
    if ($site.FilesOnly) { $parameters.FilesOnly = $site.FilesOnly }
    & $publisher @parameters | Out-Null
    $state[$siteName] = $signature
    $published += $siteName
}

$state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
if ($published.Count) { "Published: $($published -join ', ')" } else { "No dashboard changes to publish." }
