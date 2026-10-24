[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Source,

    [Parameter(Mandatory)]
    [string]$SiteName,

    [string]$ServerShare = "\\BI-REPORT\PositronBI$",

    [string[]]$FilesOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SiteName) -or $SiteName -match '[\\/:*?"<>|]') {
    throw "SiteName is invalid."
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
if (-not (Test-Path -LiteralPath $ServerShare)) {
    throw "The internal publishing share is unavailable: $ServerShare"
}

$destination = Join-Path $ServerShare $SiteName
New-Item -ItemType Directory -Path $destination -Force | Out-Null

if ($FilesOnly) {
    foreach ($relativeFile in $FilesOnly) {
        $from = Join-Path $sourcePath $relativeFile
        if (-not (Test-Path -LiteralPath $from -PathType Leaf)) {
            throw "Publish file was not found: $from"
        }
        $to = Join-Path $destination $relativeFile
        New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force | Out-Null
        $temporary = "$to.publish-$PID"
        Copy-Item -LiteralPath $from -Destination $temporary -Force
        Move-Item -LiteralPath $temporary -Destination $to -Force
    }
}
else {
    $staging = Join-Path $ServerShare ".${SiteName}-staging-$PID"
    $backup = Join-Path $ServerShare ".${SiteName}-backup-$PID"
    try {
        New-Item -ItemType Directory -Path $staging -Force | Out-Null
        & robocopy $sourcePath $staging /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XD ".git" ".github" "tools" /XF "LOCAL-PUBLISHING.md" /NFL /NDL /NJH /NJS
        if ($LASTEXITCODE -gt 7) {
            throw "Copying $SiteName to the server failed (robocopy exit code: $LASTEXITCODE)."
        }
        if (Test-Path -LiteralPath $destination) {
            Move-Item -LiteralPath $destination -Destination $backup
        }
        Move-Item -LiteralPath $staging -Destination $destination
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Recurse -Force
        }
    }
    catch {
        if (-not (Test-Path -LiteralPath $destination) -and (Test-Path -LiteralPath $backup)) {
            Move-Item -LiteralPath $backup -Destination $destination
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Recurse -Force
        }
    }
}

[pscustomobject]@{
    SiteName = $SiteName
    Address = "http://bi-report.parsgrp.com:9192/$SiteName/"
    PublishedAt = (Get-Date).ToString("o")
}
