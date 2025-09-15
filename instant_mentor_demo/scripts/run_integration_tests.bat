@echo off

REM Integration Test Runner for Day 24 (Windows)
REM Run this script to execute all integration tests

echo 🧪 Starting Day 24 Integration Tests...
echo ========================================

REM Check if flutter is available
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed or not in PATH
    exit /b 1
)

echo 📱 Running Integration Tests...

REM Run integration tests
flutter test integration_test/auth_chat_integration_test.dart

if %errorlevel% equ 0 (
    echo ✅ All integration tests passed!
    echo.
    echo 📊 Test Coverage Summary:
    echo - Authentication happy path ✅
    echo - Chat message sending ✅
    echo - Error handling ✅
    echo - Offline behavior ✅
    echo - Video call join/leave ✅
    echo.
    echo 🎯 Day 24 Integration Testing: COMPLETE
) else (
    echo ❌ Some integration tests failed
    echo Check the output above for details
    exit /b 1
)

echo.
echo 🚀 Ready for Day 25 - Widget Tests!
