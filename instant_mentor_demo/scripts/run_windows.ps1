<#!
.SYNOPSIS
  Helper script to run the Windows desktop build with common feature flag presets.

.PARAMETER Mode
  Preset: prod | demo | realtime-off | simple
  Default: prod

.EXAMPLE
  ./scripts/run_windows.ps1 -Mode prod

.EXAMPLE
  ./scripts/run_windows.ps1 -Mode demo

.NOTES
  Requires Visual Studio C++ workload installed. See WINDOWS_DESKTOP_SETUP.md
#>

[CmdletBinding()]
param(
  [ValidateSet('prod','demo','realtime-off','simple')]
  [string]$Mode = 'prod'
)

function Invoke-CheckFlutter {
  $doctor = flutter doctor 2>$null
  if ($doctor -match 'Visual Studio not installed') {
    Write-Error 'Visual Studio C++ workload missing. See WINDOWS_DESKTOP_SETUP.md'
    exit 1
  }
}

Invoke-CheckFlutter

$defines = @()
$target = 'lib/main.dart'

switch ($Mode) {
  'prod'         { $defines += 'REALTIME_ENABLED=true','DEMO_MODE=false' }
  'demo'         { $defines += 'REALTIME_ENABLED=true','DEMO_MODE=true' }
  'realtime-off' { $defines += 'REALTIME_ENABLED=false','DEMO_MODE=false' }
  'simple'       { $defines += 'REALTIME_ENABLED=false','DEMO_MODE=true'; $target = 'lib/main_simple.dart' }
}

$defineArgs = $defines | ForEach-Object { "--dart-define=$_" }

Write-Host "Running mode '$Mode' with target $target" -ForegroundColor Cyan
Write-Host "Defines: $($defines -join ', ')"

flutter run -d windows -t $target @defineArgs
