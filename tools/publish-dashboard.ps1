[CmdletBinding()]
param(
    [string]$Source = (Split-Path -Parent $PSScriptRoot),
    [string]$LocalRoot = "C:\Dashboards",
    [string]$SiteName = "dashboard",
    [string]$CommitMessage = "Publish dashboard update",
    [switch]$SkipGit
)

$ErrorActionPreference = "Stop"

function Copy-SiteFiles {
    param([string]$From, [string]$To)

    New-Item -ItemType Directory -Path $To -Force | Out-Null
    & robocopy $From $To /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XD ".git" ".github" "tools" /XF "LOCAL-PUBLISHING.md"
    if ($LASTEXITCODE -gt 7) {
        throw "Local publish failed. Robocopy exit code: $LASTEXITCODE"
    }
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath ".git"))) {
    throw "Source must be a Git repository: $sourcePath"
}

if ([string]::IsNullOrWhiteSpace($SiteName) -or $SiteName -match '[\\/:*?"<>|]') {
    throw "SiteName is invalid."
}

New-Item -ItemType Directory -Path $LocalRoot -Force | Out-Null
$localRootPath = (Resolve-Path -LiteralPath $LocalRoot).Path
$targetPath = Join-Path $localRootPath $SiteName
$stagingPath = Join-Path $localRootPath ".${SiteName}-staging-$PID"
$backupPath = Join-Path $localRootPath ".${SiteName}-backup-$PID"

if ($targetPath -eq $localRootPath) {
    throw "Refusing to publish into the local root itself."
}

try {
    Copy-SiteFiles -From $sourcePath -To $stagingPath

    if (Test-Path -LiteralPath $targetPath) {
        Move-Item -LiteralPath $targetPath -Destination $backupPath
    }

    Move-Item -LiteralPath $stagingPath -Destination $targetPath

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Recurse -Force
    }
}
catch {
    if (-not (Test-Path -LiteralPath $targetPath) -and (Test-Path -LiteralPath $backupPath)) {
        Move-Item -LiteralPath $backupPath -Destination $targetPath
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}

if (-not $SkipGit) {
    $changes = & git -C $sourcePath status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Unable to read Git status." }

    if ($changes) {
        & git -C $sourcePath add --all
        if ($LASTEXITCODE -ne 0) { throw "Unable to stage Git changes." }
        & git -C $sourcePath commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) { throw "Unable to create Git commit." }
    }

    & git -C $sourcePath push origin HEAD
    if ($LASTEXITCODE -ne 0) { throw "Local publish succeeded, but GitHub push failed." }
}

[PSCustomObject]@{
    LocalPath = $targetPath
    LocalUrl = "http://localhost:8080/$SiteName/"
    GitHubPublished = -not $SkipGit
}
