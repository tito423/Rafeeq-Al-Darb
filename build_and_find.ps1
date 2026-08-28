# Build script that finds APK after build
Write-Host "Starting Flutter build..."
flutter build apk --release --split-per-abi

# Check for APKs in standard locations
$apkPaths = @()

# Standard location
$standardPath = "android/app/build/outputs/apk/release/app-release.apk"
if (Test-Path $standardPath) {
    $apkPaths += $standardPath
    Write-Host "Found APK at standard location: $standardPath"
}

# Check for split APKs
$splitPaths = Get-ChildItem -Path "android/app/build/outputs/apk" -Recurse -Filter *.apk -ErrorAction SilentlyContinue
foreach ($apk in $splitPaths) {
    $apkPaths += $apk.FullName
    Write-Host "Found APK: $($apk.FullName)"
}

# Check project root build directory (where error suggests APK might be)
$rootBuildPaths = Get-ChildItem -Path "build" -Recurse -Filter *.apk -ErrorAction SilentlyContinue
foreach ($apk in $rootBuildPaths) {
    $apkPaths += $apk.FullName
    Write-Host "Found APK in root build: $($apk.FullName)"
}

if ($apkPaths.Count -eq 0) {
    Write-Host "ERROR: No APK files found after build!"
    Write-Host "Checking build directory structure..."
    Get-ChildItem -Path "android/app/build" -Recurse -Directory | Select-Object -First 20
    exit 1
} else {
    Write-Host "SUCCESS: Found $($apkPaths.Count) APK file(s)"
    # Use the first APK found
    $mainApk = $apkPaths[0]
    Write-Host "Using APK: $mainApk"
    
    # Upload to GitHub release
    Write-Host "Uploading to GitHub release v2.1.2..."
    gh release upload v2.1.2 $mainApk
    Write-Host "Upload completed!"
}