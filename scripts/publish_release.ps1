# Build, sign and publish one GitHub release - also the backup path when a
# session dies mid-release. Usage (PowerShell, repo root):
#   .\scripts\publish_release.ps1 -Version 3.99.0 -Notes dist\notes_3.99.0.md
# In order (CLAUDE.md 2.3):
#   1. pubspec.yaml carries the version and HEAD is pushed to master;
#   2. stops the emulator (TRAPS 24) and builds with build_github_release.bat
#      (signed, with the support link; TRAPS 75 for the cmd/chcp form) -
#      skipped when dist\RafeeqAlDarb-v<Version>.apk already exists;
#   3. deletes every other app release + tag EXCEPT v3.87.0 and content-*;
#   4. creates v<Version> from master with the APK and the Arabic notes
#      (skipped when it already exists, so a rerun finishes a half release);
#   5. checks the tag SHA = HEAD and the asset sha256 = the local APK.
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Notes
)
$ErrorActionPreference = 'Stop'
$repo = 'tito423/Rafeeq-Al-Darb'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pub = Select-String -Path rafeeq_app\pubspec.yaml -Pattern '^version:\s*(\S+)'
$pubVer = $pub.Matches[0].Groups[1].Value.Split('+')[0]
if ($pubVer -ne $Version) { throw "pubspec says $pubVer, not $Version - bump it first" }
if (-not (Test-Path $Notes)) { throw "notes file $Notes not found" }
git fetch -q origin master
if ((git rev-parse HEAD) -ne (git rev-parse origin/master)) { throw 'HEAD is not pushed to origin/master' }

$apk = "dist\RafeeqAlDarb-v$Version.apk"
if (-not (Test-Path $apk)) {
    Stop-Process -Name emulator, qemu-system-x86_64-headless -Force -ErrorAction SilentlyContinue
    . .\scripts\flutter_env.ps1 | Out-Null
    $ErrorActionPreference = 'Continue'
    $env:JAVA_TOOL_OPTIONS = '-Djavax.net.ssl.trustStore=E:\DevEnv\gradle\rafeeq-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit'
    cmd /c "chcp 65001 && call `"$root\build_github_release.bat`"" *> "dist\build_$Version.log"
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { throw "build failed - see dist\build_$Version.log" }
    Copy-Item rafeeq_app\build\app\outputs\flutter-apk\app-release.apk $apk
}
$localSha = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()

$keep = @('v3.87.0', 'content-mirror', 'content-mushaf', 'content-surah', "v$Version")
$tags = @(gh release list -R $repo --limit 50 --json tagName --jq '.[].tagName')
foreach ($t in $tags) {
    if ($keep -notcontains $t) { gh release delete $t -R $repo --yes --cleanup-tag }
}
if ($tags -notcontains "v$Version") {
    gh release create "v$Version" $apk -R $repo --target master --title "رفيق الدرب $Version" --notes-file $Notes
}

$tagSha = ((git ls-remote origin "refs/tags/v$Version") -split "`t")[0]
$head = git rev-parse HEAD
$digest = gh release view "v$Version" -R $repo --json assets --jq '.assets[0].digest'
"tag   $tagSha"; "HEAD  $head"; "asset $digest"; "local sha256:$localSha"
if ($tagSha -ne $head) { throw 'tag does not point at HEAD' }
if ($digest -ne "sha256:$localSha") { throw 'GitHub asset differs from the local APK' }
"OK https://github.com/$repo/releases/tag/v$Version"
"APK https://github.com/$repo/releases/download/v$Version/RafeeqAlDarb-v$Version.apk"
