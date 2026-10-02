# Registers the scheduled task «RafeeqMirrorWatchdog»: runs
# recitation_mirror_watchdog.ps1 every 10 minutes, for this user, with no
# window (through wscript). Remove it with:
#   Unregister-ScheduledTask -TaskName RafeeqMirrorWatchdog -Confirm:$false
$root = Split-Path -Parent $PSScriptRoot
$vbs = Join-Path $root 'scripts\out\recitation_watchdog.vbs'
$ps1 = Join-Path $root 'scripts\recitation_mirror_watchdog.ps1'
Set-Content -Path $vbs -Encoding ascii -Value @"
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$ps1""", 0, False
"@
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
# runs on battery too, and catches up after the PC wakes
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName RafeeqMirrorWatchdog -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Get-ScheduledTask -TaskName RafeeqMirrorWatchdog | Select-Object TaskName, State
