Write-Host 'Building optimized APK...'
flutter clean
flutter pub get
flutter build apk --release
if (Test-Path 'android/app/build/outputs/apk/release/app-release.apk') {
    gh release upload v1.0.0 android/app/build/outputs/apk/release/app-release.apk --clobber
    Write-Host 'GitHub Release Uploaded Successfully!'
} else {
    Write-Host 'APK not found after build!'
}
