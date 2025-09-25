Windows Desktop Setup Guide
================================

Goal: Enable building and running the Flutter Windows desktop app in `instant_mentor_demo`.

## 1. Prerequisites

- Windows 10/11 64-bit (you have this: 11 Pro 24H2 OK)
- Flutter SDK (already installed: 3.35.2)
- Git (already present if Flutter works)
- Visual Studio 2022 (Community is fine) with the C++ desktop toolchain

## 2. Install Visual Studio Components

1. Download Visual Studio 2022 Community:
   https://visualstudio.microsoft.com/downloads/
2. During installation select the workload:
   - "Desktop development with C++"
3. In the right-side (summary) pane ensure these (most come pre‑selected, verify):
   - MSVC v143 C++ x64/x86 build tools
   - Windows 11 SDK (latest) (Windows 10 SDK also fine if offered)
   - C++ CMake tools for Windows
   - C++ ATL for latest v143 build tools (optional)
   - C++ MFC for latest v143 build tools (optional)
   - CMake integration
   - Ninja build system
   - Windows Debugging Tools (if listed)
   - Spectre-mitigated libraries (optional but recommended)

If you already installed VS without these, open the Visual Studio Installer, choose *Modify* → add the workload and components → Apply.

### Offline / Limited Bandwidth (Optional)
Create an offline layout (example):
```
vs_community.exe --layout C:\VSLayout --lang en-US
```
Then run the installer from that layout folder later.

## 3. Verify Installation

After install completes, open a fresh PowerShell (so PATH updates propagate) and run:
```
flutter doctor -v
```
Expected change: The Visual Studio section should have a green check instead of:
```
[X] Visual Studio - develop Windows apps
```

## 4. Clean & Rebuild Windows Target

From the project directory (`instant_mentor_demo`):
```
flutter clean
flutter pub get
flutter run -d windows -t lib\main.dart --dart-define=REALTIME_ENABLED=true --dart-define=DEMO_MODE=false
```

If you want a faster minimal startup (fewer features):
```
flutter run -d windows -t lib\main_simple.dart
```

## 5. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Still shows `[X] Visual Studio` | Opened old shell | Open a new terminal then re-run doctor |
| Error about CMake/Ninja missing | Components skipped | Modify VS install and add CMake + Ninja |
| Build stops at generating plugin registrant | Normal early stage | Wait unless an explicit error appears |
| Linker errors referencing libs | Incomplete MSVC install | Ensure v143 build tools + Windows SDK |
| PATH too long errors | Long install path | Shorten project path or enable long paths in Windows registry |

## 6. (Optional) Android Toolchain Fix
Not required for Windows, but to clear doctor warnings later:
```
flutter doctor --android-licenses
```
If cmdline-tools missing, install via Android Studio SDK Manager → *Android SDK Command-line Tools (latest)*.

## 7. Re-running With Different Feature Flags
```
flutter run -d windows -t lib\main.dart ^
  --dart-define=REALTIME_ENABLED=true ^
  --dart-define=DEMO_MODE=false
```
To disable realtime temporarily:
```
--dart-define=REALTIME_ENABLED=false
```

## 8. CI / Future Automation (Outline)
For automated Windows builds (e.g., GitHub Actions self-hosted runner):
- Pre-install Visual Studio workload
- Cache Flutter (`flutter --version` to warm up)
- Run: `flutter build windows --dart-define=REALTIME_ENABLED=true --dart-define=DEMO_MODE=false`

## 9. When to Re-run `flutter create .`
Only if the `windows/` folder becomes corrupted or was deleted. (It already exists in this repo—do NOT overwrite unless necessary.)

## 10. Support Checklist
Before filing an issue, gather:
```
flutter doctor -v
flutter run -d windows -t lib/main.dart -v > build_log.txt 2>&1
dir windows\\runner
``` 
Attach `build_log.txt`.

---
Once Visual Studio is installed and doctor is green for Windows, return to the main task list and attempt the run command. 
