@echo off
REM Comprehensive test runner script with CI/CD integration and performance monitoring
echo 🚀 Starting comprehensive test suite with CI/CD integration...

REM Test results
set UNIT_TEST_RESULT=0
set WIDGET_TEST_RESULT=0
set INTEGRATION_TEST_RESULT=0
set PERFORMANCE_TEST_RESULT=0

REM Create results directories
if not exist test_results mkdir test_results
if not exist test_reports mkdir test_reports
if not exist coverage mkdir coverage
if not exist artifacts mkdir artifacts

echo.
echo 📋 Running Flutter Doctor...
call flutter doctor

echo.
echo 📦 Getting dependencies...
call flutter pub get

echo.
echo 🔍 Running Flutter Analyze...
call flutter analyze --write=artifacts/analysis_results.txt
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter analyze failed
    exit /b 1
)

echo.
echo 🧪 Running Unit Tests with Coverage...
call flutter test test/unit/ --coverage --reporter=expanded --file-reporter=json:test_results/unit_tests.json
set UNIT_TEST_RESULT=%ERRORLEVEL%

echo.
echo 🎨 Running Widget Tests...
call flutter test test/widget_test.dart --reporter=expanded --file-reporter=json:test_results/widget_tests.json
set WIDGET_TEST_RESULT=%ERRORLEVEL%

echo.
echo 🔗 Running Integration Tests...
call flutter test integration_test/ --reporter=expanded --file-reporter=json:test_results/integration_tests.json
set INTEGRATION_TEST_RESULT=%ERRORLEVEL%

echo.
echo ⚡ Running Performance Integration Tests...
call flutter test integration_test/comprehensive_performance_test.dart --reporter=expanded --file-reporter=json:test_results/performance_tests.json
set PERFORMANCE_TEST_RESULT=%ERRORLEVEL%

echo.
echo 📊 Generating Coverage Reports...
if exist "coverage\lcov.info" (
    echo ✅ Coverage data found
    copy coverage\lcov.info test_reports\ >nul 2>&1
    echo ✅ Coverage reports generated
) else (
    echo ⚠️ No coverage data found
)

echo.
echo 🏗️ Building Release APK for Testing...
call flutter build apk --release --target-platform=android-arm64 >nul 2>&1
if %ERRORLEVEL% equ 0 (
    copy build\app\outputs\flutter-apk\app-release.apk artifacts\ >nul 2>&1
    echo ✅ Release APK built and archived
) else (
    echo ⚠️ APK build skipped (not on Android platform)
)

echo.
echo 📈 Generating Performance Reports...
echo ^<!DOCTYPE html^> > test_reports\performance_summary.html
echo ^<html^>^<head^>^<title^>Performance Test Summary^</title^>^</head^> >> test_reports\performance_summary.html
echo ^<body^>^<h1^>🚀 InstantMentor Performance Test Results^</h1^> >> test_reports\performance_summary.html
echo ^<p^>Generated: %date% %time%^</p^>^</body^>^</html^> >> test_reports\performance_summary.html

echo.
echo � Analyzing Test Results...
set FAILED_TESTS=0

echo.
echo 📊 Final Test Results Summary:
echo ==============================

if %UNIT_TEST_RESULT% equ 0 (
    echo Unit Tests: ✅ PASSED
) else (
    echo Unit Tests: ❌ FAILED
    set /a FAILED_TESTS+=1
)

if %WIDGET_TEST_RESULT% equ 0 (
    echo Widget Tests: ✅ PASSED
) else (
    echo Widget Tests: ❌ FAILED
    set /a FAILED_TESTS+=1
)

if %INTEGRATION_TEST_RESULT% equ 0 (
    echo Integration Tests: ✅ PASSED
) else (
    echo Integration Tests: ❌ FAILED
    set /a FAILED_TESTS+=1
)

if %PERFORMANCE_TEST_RESULT% equ 0 (
    echo Performance Tests: ✅ PASSED
) else (
    echo Performance Tests: ❌ FAILED
    set /a FAILED_TESTS+=1
)

echo.
echo 📈 Statistics:
echo Failed test suites: %FAILED_TESTS%/4

echo.
if %FAILED_TESTS% equ 0 (
    echo 🎉 All tests passed! CI/CD pipeline ready for deployment.
    echo 📁 Artifacts ready in: artifacts\, test_results\, test_reports\, coverage\
    exit /b 0
) else (
    echo 💥 %FAILED_TESTS% test suite^(s^) failed! Check the reports for details.
    echo 🔍 Review files: test_reports\performance_summary.html
    exit /b 1
)
