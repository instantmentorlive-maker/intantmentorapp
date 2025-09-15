param(
    [switch]$Clean,
    [string]$Device = 'chrome',
    [string]$Target = 'lib/main.dart'
)

Write-Host '=== Instant Mentor Demo Run Helper ===' -ForegroundColor Cyan
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Join-Path $scriptRoot '..'
Set-Location $projectRoot

if (-Not (Test-Path 'pubspec.yaml')) {
    Write-Error 'pubspec.yaml not found. Make sure this script resides in the scripts folder inside the Flutter project.'
    exit 1
}

if ($Clean) {
    Write-Host 'Cleaning build artifacts...' -ForegroundColor Yellow
    flutter clean
}

Write-Host 'Fetching dependencies...' -ForegroundColor Yellow
flutter pub get

Write-Host "Launching Flutter app on device: $Device (target: $Target)" -ForegroundColor Green
flutter run -d $Device -t $Target --web-renderer canvaskit
