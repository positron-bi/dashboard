[CmdletBinding()]
param(
    [string]$LocalRoot = "C:\Dashboards"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $LocalRoot)) {
    throw "Local dashboard folder does not exist: $LocalRoot"
}

$sites = Get-ChildItem -LiteralPath $LocalRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName ".git")
}

foreach ($site in $sites) {
    Write-Host "Syncing $($site.Name)…"
    & git -C $site.FullName pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not sync $($site.Name)."
    }
}
