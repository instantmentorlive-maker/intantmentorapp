@echo off
setlocal
pushd %~dp0

echo Running Flutter Web on fixed port 8080 (Chrome)...
flutter config --enable-web >nul 2>&1
flutter run -d chrome --web-port 8080 --target=lib/main.dart

popd
endlocal
