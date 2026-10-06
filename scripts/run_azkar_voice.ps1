# Daily resume of scripts/azkar_voice_all.py after Gemini TTS's daily limit
# (100 requests/day on Tier 1) resets. Scheduled task «RafeeqAzkarVoice»,
# 01:05 Dubai, created 2026-10-06 on the owner's word («اعمل المهام
# المجدولة»). The script is resumable: finished clips and items are kept.
# Remove the task once items.json holds every voiced dhikr:
#   schtasks /Delete /TN RafeeqAzkarVoice /F
Set-Location "E:\My Projects\Rafiq-Al-Darb"
$log = "scripts\out\azkar_voice_all.log"
Add-Content $log "`n===== run $(Get-Date -Format s) ====="
& py -3 -u scripts\azkar_voice_all.py *>> $log
