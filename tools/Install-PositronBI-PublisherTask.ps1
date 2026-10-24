[CmdletBinding()]
param(
    [string]$ServerShare = "\\BI-REPORT\PositronBI$",
    [ValidateRange(1, 60)]
    [int]$IntervalMinutes = 1,
    [string]$TaskName = "Positron BI Server Publisher"
)

$ErrorActionPreference = "Stop"
$syncScript = Join-Path $PSScriptRoot "Sync-PositronBI-Sites.ps1"
if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Sync script was not found: $syncScript"
}

$powerShell = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$syncScript`" -ServerShare `"$ServerShare`""
$action = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

[pscustomobject]@{
    TaskName = $TaskName
    Interval = "$IntervalMinutes minute(s)"
    RunsWhen = "The publishing Windows user is signed in"
    ServerShare = $ServerShare
}
