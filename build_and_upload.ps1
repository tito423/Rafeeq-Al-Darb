Write-Host "Starting APK build..."
flutter build apk --release
if (Test-Path "android/app/build/outputs/apk/release/app-release.apk") {
    Write-Host "APK built successfully. Uploading to GitHub release v2.1.2..."
    gh release upload v2.1.2 android/app/build/outputs/apk/release/app-release.apk
    Write-Host "Upload completed."
} else {
    Write-Host "APK not found after build!"
    exit 1
}