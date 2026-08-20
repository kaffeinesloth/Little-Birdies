param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string]$LaptopIp
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$MobileRoot = Join-Path $ProjectRoot 'mobile'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter was not found. Install Flutter stable and add it to PATH first.'
}

Push-Location -LiteralPath $MobileRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    flutter build apk --release `
        --dart-define="API_BASE_URL=http://${LaptopIp}:8000" `
        --dart-define="AI_BASE_URL=http://${LaptopIp}:8001"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
} finally {
    Pop-Location
}

$ApkPath = Join-Path $MobileRoot 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host "APK ready: $ApkPath" -ForegroundColor Green
Write-Host "The phone and laptop must share Wi-Fi, and TCP ports 8000 and 8001 must be reachable."
