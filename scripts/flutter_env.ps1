# Select the project's verified SDK in this PowerShell session.
# The previous SDK remains installed for the 3.87 rollback checkout.
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskExpected = (Get-Content -LiteralPath "$taskRepo\.flutter-version" -Raw).Trim()
$taskSdk = if ($env:RAFEEQ_FLUTTER_SDK) {
    $env:RAFEEQ_FLUTTER_SDK
} else {
    "E:\DevEnv\flutter-$taskExpected"
}
$taskFlutter = Join-Path $taskSdk 'bin\flutter.bat'
if (-not (Test-Path -LiteralPath $taskFlutter)) {
    throw "Project Flutter SDK unavailable: $taskSdk. Set RAFEEQ_FLUTTER_SDK to the verified SDK directory."
}
$taskVersion = (& $taskFlutter --version --machine | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $taskVersion.frameworkVersion -ne $taskExpected) {
    throw "Project requires Flutter $taskExpected; SDK selection was rejected."
}
$env:Path = "$(Join-Path $taskSdk 'bin');$env:Path"
Write-Host "Project Flutter $taskExpected selected for this session."
