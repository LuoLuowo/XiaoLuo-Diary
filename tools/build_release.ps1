$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($projectRoot -match '[^\x00-\x7F]') {
    throw 'Build using the ASCII drive mapping (for example: Z:\tools\build_release.ps1). Do not switch project paths within an incremental build.'
}
Push-Location $projectRoot
try {
    & flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed' }
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed' }
    & flutter build apk --release --no-pub --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed' }
    & "$PSScriptRoot\verify_apk_assets.ps1" -ApkPath 'build\app\outputs\flutter-apk\app-release.apk'
} finally { Pop-Location }
