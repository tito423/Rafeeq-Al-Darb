# Comprehensive APK Build and Upload Script
# This script will build the APK and upload it to GitHub Releases

$ErrorActionPreference = "Stop"
$startTime = Get-Date
$logFile = "build_process_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Add-Content -Path $logFile
    Write-Host $Message
}

try {
    Write-Log "Starting APK build process for Rafeeq Al-Darb v2.1.2"
    Write-Log "Working directory: $(Get-Location)"
    
    # Step 1: Flutter clean
    Write-Log "Step 1: Running flutter clean..."
    flutter clean 2>&1 | Out-File -Append -FilePath $logFile
    
    # Step 2: Get dependencies
    Write-Log "Step 2: Getting Flutter dependencies..."
    flutter pub get 2>&1 | Out-File -Append -FilePath $logFile
    
    # Step 3: Build APK with detailed logging
    Write-Log "Step 3: Building release APK (this may take several minutes)..."
    
    # Build with verbose output and timeout handling
    $buildStart = Get-Date
    $process = Start-Process -FilePath "flutter" `
        -ArgumentList "build apk --release --verbose" `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput "build_stdout.txt" `
        -RedirectStandardError "build_stderr.txt"
    
    # Wait with timeout (10 minutes)
    $timeoutSeconds = 600
    $process.WaitForExit($timeoutSeconds * 1000)
    
    if (-not $process.HasExited) {
        $process.Kill()
        throw "Build timed out after $timeoutSeconds seconds"
    }
    
    $buildDuration = (Get-Date) - $buildStart
    Write-Log "Build completed in $($buildDuration.TotalSeconds) seconds with exit code $($process.ExitCode)"
    
    if ($process.ExitCode -ne 0) {
        Write-Log "Build failed. Checking error output..."
        Get-Content "build_stderr.txt" -Tail 50 | ForEach-Object { Write-Log "ERROR: $_" }
        throw "Flutter build failed with exit code $($process.ExitCode)"
    }
    
    # Step 4: Find the generated APK(s)
    Write-Log "Step 4: Searching for generated APK files..."
    
    $apkFiles = @()
    
    # Check standard locations
    $locations = @(
        "android/app/build/outputs/apk/release/app-release.apk",
        "android/app/build/outputs/apk/release/*.apk",
        "build/app/outputs/apk/release/*.apk",
        "build/app/outputs/flutter-apk/*.apk",
        "build/*.apk"
    )
    
    foreach ($pattern in $locations) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($file in $found) {
            $apkFiles += $file.FullName
            Write-Log "Found APK: $($file.FullName) ($($file.Length / 1MB) MB)"
        }
    }
    
    if ($apkFiles.Count -eq 0) {
        Write-Log "No APK files found in standard locations. Searching recursively..."
        $allApks = Get-ChildItem -Path . -Recurse -Filter *.apk -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.gradle\*" -and $_.FullName -notlike "*\.android\*" }
        foreach ($file in $allApks) {
            $apkFiles += $file.FullName
            Write-Log "Found APK (recursive search): $($file.FullName) ($($file.Length / 1MB) MB)"
        }
    }
    
    if ($apkFiles.Count -eq 0) {
        throw "No APK files generated. Build may have failed silently."
    }
    
    # Step 5: Select the main APK (prefer release flavor)
    $mainApk = $apkFiles | Where-Object { $_ -like "*release*" -or $_ -like "*app-release*" } | Select-Object -First 1
    if (-not $mainApk) {
        $mainApk = $apkFiles[0]
    }
    
    Write-Log "Selected APK for upload: $mainApk"
    
    # Step 6: Verify APK version
    Write-Log "Step 5: Verifying APK information..."
    
    # Try to get basic info about the APK
    $fileInfo = Get-Item $mainApk
    Write-Log "APK File: $($fileInfo.Name)"
    Write-Log "Size: $($fileInfo.Length / 1MB) MB"
    Write-Log "Last Modified: $($fileInfo.LastWriteTime)"
    
    # Step 7: Upload to GitHub Release
    Write-Log "Step 6: Uploading to GitHub Release v2.1.2..."
    
    # Check if release exists
    Write-Log "Checking GitHub release status..."
    $releaseCheck = gh release view v2.1.2 --json tagName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Release v2.1.2 doesn't exist or can't be accessed"
        Write-Log "Creating release v2.1.2..."
        gh release create v2.1.2 --title "Rafeeq Al-Darb v2.1.2" --notes "Release v2.1.2" 2>&1 | Out-File -Append -FilePath $logFile
    }
    
    Write-Log "Uploading APK to GitHub..."
    $uploadResult = gh release upload v2.1.2 "$mainApk" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "SUCCESS: APK uploaded to GitHub Release v2.1.2!"
        Write-Log "Download URL: https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v2.1.2"
    } else {
        Write-Log "Upload failed: $uploadResult"
        throw "GitHub upload failed"
    }
    
    # Step 8: Final summary
    $totalDuration = (Get-Date) - $startTime
    Write-Log "========================================="
    Write-Log "BUILD AND UPLOAD COMPLETED SUCCESSFULLY!"
    Write-Log "Total time: $($totalDuration.TotalMinutes) minutes"
    Write-Log "APK file: $mainApk"
    Write-Log "GitHub Release: https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v2.1.2"
    Write-Log "========================================="
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    Write-Host "Build failed. Check $logFile for details." -ForegroundColor Red
    exit 1
}