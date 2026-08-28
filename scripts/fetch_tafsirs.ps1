$ProgressPreference = 'SilentlyContinue'
$out = "e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1\tafsir_qc"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($id in @(91, 14)) {
    for ($ch = 1; $ch -le 114; $ch++) {
        $path = Join-Path $out ("{0}_ch{1}.json" -f $id, $ch)
        if (Test-Path $path) { continue }
        try {
            $r = Invoke-RestMethod "https://api.quran.com/api/v4/quran/tafsirs/${id}?chapter_number=${ch}" -TimeoutSec 30
            $r | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $path -Encoding UTF8
        } catch {
            ("{0} ch{1}: {2}" -f $id, $ch, $_.Exception.Message) | Out-File (Join-Path $out ("{0}_ch{1}_err.txt" -f $id, $ch)) -Encoding ascii
        }
        Start-Sleep -Milliseconds 150
    }
}
"DONE" | Out-File (Join-Path $out "_complete.txt") -Encoding ascii
