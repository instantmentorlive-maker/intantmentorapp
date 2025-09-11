@echo off
REM Unit Test Runner for Instant Mentor App (Windows)

echo 🧪 Running Instant Mentor Unit Tests
echo ==================================

REM Run only unit tests (excluding widget tests)
flutter test test/unit/

REM Check if tests passed
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ All unit tests passed!
    echo.
    echo 📊 Test Coverage Summary:
    echo - Core Utils Tests: ✅ 21 tests
    echo - User Model Tests: ✅ 21 tests
    echo - Mock Auth Repository Tests: ✅ 26 tests
    echo - Total Unit Tests: ✅ 68 tests
) else (
    echo.
    echo ❌ Some tests failed
    exit /b 1
)
