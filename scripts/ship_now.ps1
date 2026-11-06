# Bump the minor version, commit everything tracked + lib/test changes, push, build and publish.
# Usage (repo root): .\scripts\ship_now.ps1
$ErrorActionPreference = 'Continue'  # git writes warnings to stderr (PS 5.1 NativeCommandError)
Set-Location (Split-Path -Parent $PSScriptRoot)
$line = (Select-String rafeeq_app\pubspec.yaml -Pattern '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)').Matches[0].Groups
$v = "$($line[1].Value).$([int]$line[2].Value + 1).0"; $b = [int]$line[4].Value + 1
(Get-Content rafeeq_app\pubspec.yaml) -replace '^version:.*', "version: $v+$b" | Set-Content rafeeq_app\pubspec.yaml -Encoding utf8
git add -u rafeeq_app scripts TASK_FOLLOWUP.md; git add rafeeq_app/lib rafeeq_app/assets/translations
git commit -m "Release $v (khatma: rub' marker, bookmark resume, card tap, multiple reminders)`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin master
$notes = "dist\notes_$v.md"
if (-not (Test-Path $notes)) { Set-Content $notes "## رفيق الدرب $v`n`n- الختمة: علامة الربع، الرجوع لمكان القراءة، فتح الكارت بلمسة، أكثر من تذكير.`n`nلم تُجرَّب على المحاكي قبل النشر (بطلب صاحب التطبيق)." -Encoding utf8 }
& .\scripts\publish_release.ps1 -Version $v -Notes $notes
