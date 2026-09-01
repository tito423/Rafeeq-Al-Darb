<#
  Runs the Flutter toolchain and writes the result into the project folder,
  where Claude can read it.

  Claude works from an isolated Linux sandbox that has only this folder mounted:
  no Flutter, no Windows shell, and the Dart/Flutter SDK downloads are blocked
  by the sandbox's network policy. So it cannot compile the app itself. It can,
  however, read any file inside this folder — which is all this script needs to
  bridge the gap.

  Usage:
      .\scripts\check.ps1              # run once
      .\scripts\check.ps1 -Watch       # re-run every 20s until you press Ctrl+C
      .\scripts\check.ps1 -Watch -Every 60
#>
param(
    [switch]$Watch,
    [int]$Every = 20
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$app  = Join-Path $root 'rafeeq_app'
$out  = Join-Path $PSScriptRoot '_check_output.txt'

function Invoke-Check {
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# rafeeq check")
    $null = $sb.AppendLine("# started : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $null = $sb.AppendLine("# app dir : $app")
    $null = $sb.AppendLine()

    Push-Location $app
    try {
        $null = $sb.AppendLine("===== flutter --version =====")
        $null = $sb.AppendLine((& flutter --version 2>&1 | Out-String).Trim())
        $null = $sb.AppendLine()

        $null = $sb.AppendLine("===== flutter pub get =====")
        $pubOut = (& flutter pub get 2>&1 | Out-String).Trim()
        $pubCode = $LASTEXITCODE
        $null = $sb.AppendLine($pubOut)
        $null = $sb.AppendLine("exit code: $pubCode")
        $null = $sb.AppendLine()

        $null = $sb.AppendLine("===== flutter analyze =====")
        $anOut = (& flutter analyze 2>&1 | Out-String).Trim()
        $anCode = $LASTEXITCODE
        $null = $sb.AppendLine($anOut)
        $null = $sb.AppendLine("exit code: $anCode")
        $null = $sb.AppendLine()

        $null = $sb.AppendLine("===== summary =====")
        $null = $sb.AppendLine("pub get  : $(if ($pubCode -eq 0) {'OK'} else {'FAILED'})")
        $null = $sb.AppendLine("analyze  : $(if ($anCode -eq 0) {'CLEAN'} else {'ISSUES'})")
    }
    finally {
        Pop-Location
    }

    $null = $sb.AppendLine("# finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    Set-Content -Path $out -Value $sb.ToString() -Encoding UTF8
    Write-Host "-> wrote $out" -ForegroundColor Green
}

if ($Watch) {
    Write-Host "Watching. Re-running every $Every s. Ctrl+C to stop." -ForegroundColor Cyan
    while ($true) {
        Invoke-Check
        Start-Sleep -Seconds $Every
    }
} else {
    Invoke-Check
}
