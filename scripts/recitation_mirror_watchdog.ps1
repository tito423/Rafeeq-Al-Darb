# Keeps the two R7 copy runs (github_mirror_recitations.py) going until both
# are finished, with nobody at the PC. Run every 10 minutes by the scheduled
# task «RafeeqMirrorWatchdog» (scripts/install_recitation_watchdog.ps1).
#
# Owner, 2026-10-02: «اعمل اسكريبت يشتغل اليا في النسخ والرفع ويبقى عارف
# هيعمل ايه لو تحميل او نسخ وقف».
#
# For each kind (surah, ayah):
#   finished  - its log ends with «ALL <kind> SETS PROCESSED» -> left alone
#   dead      - no process -> started again (it resumes: finished sets are
#               skipped, a half-done part re-checks what GitHub already has)
#   hung      - a process whose log has not moved for 45 minutes (it logs
#               every 50 files and every rate-limit wait) -> killed, started
# Everything it does goes to scripts/out/watchdog.log.
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'scripts\out'
$wlog = Join-Path $out 'watchdog.log'
function Note($m) { Add-Content -Path $wlog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm') $m" -Encoding utf8 }

$paces = @{ surah = 400; ayah = 800 }
foreach ($kind in 'surah', 'ayah') {
    $log = Join-Path $out "gmr_$kind.txt"
    $procs = @(Get-CimInstance Win32_Process -Filter "name='python.exe'" |
        Where-Object { $_.CommandLine -like "*github_mirror_recitations.py*--only $kind*" })
    $last = if (Test-Path $log) { Get-Content $log -Tail 1 -Encoding utf8 } else { '' }
    if ($procs.Count -eq 0 -and $last -like "*ALL $kind SETS PROCESSED*") { continue }
    if ($procs.Count -gt 0) {
        $quiet = (Get-Date) - (Get-Item $log).LastWriteTime
        if ($quiet.TotalMinutes -lt 45) { continue }
        $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Note "$kind hung (log silent $([int]$quiet.TotalMinutes) min) - killed"
        Start-Sleep 5
    } else {
        Note "$kind not running (last: $last) - starting"
    }
    Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -WorkingDirectory $root -ArgumentList @(
        '/c', "py -3 scripts\github_mirror_recitations.py --only $kind --per-hour $($paces[$kind]) >> `"$log`" 2>&1")
    Note "$kind started"
}
