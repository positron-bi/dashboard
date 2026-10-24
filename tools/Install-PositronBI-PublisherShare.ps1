[CmdletBinding()]
param(
    [string]$WebRoot = "C:\inetpub\PositronBI-Dashboard",
    [string]$ShareName = "PositronBI$",
    [string]$PublisherAccount = "PARS\a.farshchian"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $WebRoot -PathType Container)) {
    throw "The IIS dashboard folder was not found: $WebRoot"
}

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($share -and $share.Path -ne $WebRoot) {
    throw "The existing share $ShareName points to a different folder: $($share.Path)"
}
if (-not $share) {
    New-SmbShare -Name $ShareName -Path $WebRoot -ChangeAccess $PublisherAccount -FullAccess "Administrators" | Out-Null
}

$acl = Get-Acl -LiteralPath $WebRoot
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $PublisherAccount,
    "Modify",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
if (-not ($acl.Access | Where-Object { $_.IdentityReference -eq $PublisherAccount -and $_.FileSystemRights.ToString().Contains("Modify") })) {
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $WebRoot -AclObject $acl
}

[pscustomobject]@{
    Share = "\\$env:COMPUTERNAME\$ShareName"
    Publisher = $PublisherAccount
    Path = $WebRoot
}
