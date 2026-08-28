$startTime = Get-Date
$process = Start-Process -FilePath "flutter" -ArgumentList "build apk --release" -PassThru -NoNewWindow -WorkingDirectory "E:\My Projects\Rafiq-Al-Darb\rafeeq_app"
while (-not $process.HasExited) {
    Start-Sleep -Seconds 30
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalMinutes -gt 10) {
        Write-Host "Build timed out after 10 minutes"
        $process.Kill()
        exit 1
    }
}
if ($process.ExitCode -eq 0) {
    Write-Host "Build succeeded"
} else {
    Write-Host "Build failed with exit code $($process.ExitCode)"
    exit $process.ExitCode
}