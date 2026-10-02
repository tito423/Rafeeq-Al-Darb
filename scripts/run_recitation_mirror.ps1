# Starts the two R7 copy runs (scripts/github_mirror_recitations.py) as
# detached Windows processes, so they keep going after the Claude session
# that started them ends. Safe to run again: a run already going is left
# alone, and a stopped one resumes where it stopped.
#   powershell -ExecutionPolicy Bypass -File scripts\run_recitation_mirror.ps1
# Before publishing an app release, stop both (TRAPS.md #60):
#   powershell -ExecutionPolicy Bypass -File scripts\run_recitation_mirror.ps1 -Stop
param([switch]$Stop)
$root = Split-Path -Parent $PSScriptRoot
$running = Get-CimInstance Win32_Process -Filter "name='python.exe'" |
    Where-Object { $_.CommandLine -like '*github_mirror_recitations.py*' }
if ($Stop) {
    $running | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    "stopped $(@($running).Count) run(s)"
    return
}
foreach ($job in @(@{kind = 'surah'; pace = 400}, @{kind = 'ayah'; pace = 800})) {
    if ($running | Where-Object { $_.CommandLine -like "*--only $($job.kind)*" }) {
        "$($job.kind): already running"
        continue
    }
    $log = Join-Path $root "scripts\out\gmr_$($job.kind).txt"
    Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -WorkingDirectory $root -ArgumentList @(
        '/c', "py -3 scripts\github_mirror_recitations.py --only $($job.kind) --per-hour $($job.pace) >> `"$log`" 2>&1")
    "$($job.kind): started"
}
