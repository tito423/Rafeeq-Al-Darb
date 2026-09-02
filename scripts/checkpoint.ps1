<#
  One command that makes a dead session survivable.

  Agents run out of quota mid-task. Whatever lives only in the agent's head at
  that moment is lost. This script pins that state to disk and to git in a
  single step, so the next agent resumes from a written note instead of
  guessing from a half-edited working tree.

  Run it often — after every meaningful edit, not once per stage.

      .\scripts\checkpoint.ps1 "wired adhan preview button"
      .\scripts\checkpoint.ps1 "adhan alarm fires on locked screen" -Done
      .\scripts\checkpoint.ps1 -Status          # just show where things stand
#>
param(
    [Parameter(Position = 0)][string]$Note = "",
    [switch]$Done,
    [switch]$Status
)

$ErrorActionPreference = 'Continue'
$root     = Split-Path -Parent $PSScriptRoot
$handover = Join-Path $root 'HANDOVER.md'
Push-Location $root

# HANDOVER.md is UTF-8 with Arabic text and em-dashes. Windows PowerShell 5.1's
# Get-Content/Set-Content default to the system ANSI codepage, which silently
# mangles every non-ASCII byte on a read/write round-trip (this corrupted the
# whole file once — restored from git). Always go through these two helpers.
function Read-Utf8 ($path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }
function Write-Utf8 ($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

if ($Status) {
    Write-Host "`n=== last 5 commits ===" -ForegroundColor Cyan
    git log --oneline -5
    Write-Host "`n=== uncommitted ===" -ForegroundColor Cyan
    $st = git status --short
    if ($st) { $st } else { Write-Host "(clean)" -ForegroundColor Green }
    Write-Host "`n=== work in progress (from HANDOVER.md) ===" -ForegroundColor Cyan
    $t = Read-Utf8 $handover
    if ($t -match '(?s)<!-- WIP:START -->(.*?)<!-- WIP:END -->') { $Matches[1].Trim() }
    Pop-Location; exit 0
}

if (-not $Note) {
    Write-Host "Usage: .\scripts\checkpoint.ps1 ""what you just did""" -ForegroundColor Yellow
    Pop-Location; exit 1
}

# Guard: Git Bash turns a bare "/s" / "/status" into a path like "S:/". If that
# reaches here as the note, the caller meant -Status, not a checkpoint.
if ($Note -match '^[A-Za-z]:[\\/]?$') {
    Write-Host "Looks like a mangled '/s' ('$Note'). Run 'cp /s' from cmd/PowerShell for status." -ForegroundColor Yellow
    Pop-Location; exit 1
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$state = if ($Done) { "COMPLETE" } else { "IN PROGRESS — resume here" }

# Rewrite the WIP block so a dead session always leaves a readable note.
$text = Read-Utf8 $handover
$block = @"
<!-- WIP:START -->
**$stamp — $state**

$Note

_Uncommitted at the time of writing: see ``git status``. If this says
IN PROGRESS, the previous session likely ran out of quota here — read the last
commit's diff before continuing._
<!-- WIP:END -->
"@

if ($text -match '(?s)<!-- WIP:START -->.*?<!-- WIP:END -->') {
    $text = [regex]::Replace($text, '(?s)<!-- WIP:START -->.*?<!-- WIP:END -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
} else {
    $text = $text -replace '(?m)^## 0\. TL;DR', "## Current work in progress`r`n`r`n$block`r`n`r`n---`r`n`r`n## 0. TL;DR"
}

# Refresh the freshness stamp too.
$today = Get-Date -Format 'yyyy-MM-dd'
$text = $text -replace '(?m)^\| \*\*Last updated\*\* \|.*$', "| **Last updated** | $today |"

Write-Utf8 $handover $text

git add -A | Out-Null
$prefix = if ($Done) { "checkpoint(done)" } else { "checkpoint(wip)" }
git commit -q -m "$prefix`: $Note" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0 -or (git log -1 --pretty=%s) -like "*$Note*") {
    Write-Host "checkpointed -> $(git log -1 --oneline)" -ForegroundColor Green
} else {
    Write-Host "nothing to commit (HANDOVER note still updated)" -ForegroundColor Yellow
}
Pop-Location
