while (Test-Path 'assets\data\tafsir') {
    Start-Sleep -Seconds 2
}
Write-Host 'Building APK...'
flutter clean
flutter pub get
flutter build apk --release
if (Test-Path 'android/app/build/outputs/apk/release/app-release.apk') {
    gh release create v1.0.0 android/app/build/outputs/apk/release/app-release.apk --title 'v1.0.0 Release' --notes 'Initial release of Rafiq-Al-Darb'
    Write-Host 'GitHub Release Created!'
} else {
    Write-Host 'APK not found after build!'
}
