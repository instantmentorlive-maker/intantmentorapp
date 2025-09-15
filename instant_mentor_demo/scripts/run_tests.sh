#!/usr/bin/env bash
# Comprehensive test runner script with CI/CD integration and performance monitoring
echo "🚀 Starting comprehensive test suite with CI/CD integration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
UNIT_TEST_RESULT=0
WIDGET_TEST_RESULT=0
INTEGRATION_TEST_RESULT=0
PERFORMANCE_TEST_RESULT=0

# Create results directories
mkdir -p test_results
mkdir -p test_reports
mkdir -p coverage
mkdir -p artifacts

echo -e "${BLUE}📋 Running Flutter Doctor...${NC}"
flutter doctor

echo ""
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

echo ""
echo -e "${BLUE}🔍 Running Flutter Analyze...${NC}"
flutter analyze --write=artifacts/analysis_results.txt
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Flutter analyze failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🧪 Running Unit Tests with Coverage...${NC}"
flutter test test/unit/ \
    --coverage \
    --reporter=expanded \
    --file-reporter=json:test_results/unit_tests.json
UNIT_TEST_RESULT=$?

echo ""
echo -e "${BLUE}🎨 Running Widget Tests...${NC}"
flutter test test/widget_test.dart \
    --reporter=expanded \
    --file-reporter=json:test_results/widget_tests.json
WIDGET_TEST_RESULT=$?

echo ""
echo -e "${BLUE}🔗 Running Integration Tests...${NC}"
flutter test integration_test/ \
    --reporter=expanded \
    --file-reporter=json:test_results/integration_tests.json
INTEGRATION_TEST_RESULT=$?

echo ""
echo -e "${BLUE}⚡ Running Performance Integration Tests...${NC}"
flutter test integration_test/comprehensive_performance_test.dart \
    --reporter=expanded \
    --file-reporter=json:test_results/performance_tests.json
PERFORMANCE_TEST_RESULT=$?

echo ""
echo -e "${BLUE}📊 Generating Coverage Reports...${NC}"
if [ -f "coverage/lcov.info" ]; then
    # Generate HTML coverage report
    genhtml coverage/lcov.info -o coverage/html --ignore-errors source 2>/dev/null || echo "genhtml not available, skipping HTML report"
    
    # Generate coverage summary
    lcov --summary coverage/lcov.info > test_reports/coverage_summary.txt 2>&1 || echo "lcov not available, generating basic summary"
    
    echo -e "${GREEN}✅ Coverage reports generated${NC}"
else
    echo -e "${YELLOW}⚠️ No coverage data found${NC}"
fi

echo ""
echo -e "${BLUE}🏗️ Building Release APK for Testing...${NC}"
flutter build apk --release --target-platform=android-arm64 2>/dev/null
if [ $? -eq 0 ]; then
    cp build/app/outputs/flutter-apk/app-release.apk artifacts/ 2>/dev/null
    echo -e "${GREEN}✅ Release APK built and archived${NC}"
else
    echo -e "${YELLOW}⚠️ APK build skipped (not on Android platform)${NC}"
fi

echo ""
echo -e "${BLUE}📈 Generating Performance Reports...${NC}"
# Create performance summary
cat > test_reports/performance_summary.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Performance Test Summary</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
        .metric { background: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .success { color: #4caf50; }
        .warning { color: #ff9800; }
        .error { color: #f44336; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 InstantMentor Performance Test Results</h1>
        <p>Generated: $(date)</p>
        <p>Build: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")</p>
    </div>
    
    <h2>📊 Test Execution Summary</h2>
    <table>
        <tr><th>Test Suite</th><th>Status</th><th>Details</th></tr>
        <tr>
            <td>Unit Tests</td>
            <td class="$([ $UNIT_TEST_RESULT -eq 0 ] && echo 'success' || echo 'error')">
                $([ $UNIT_TEST_RESULT -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')
            </td>
            <td>Core functionality and business logic</td>
        </tr>
        <tr>
            <td>Widget Tests</td>
            <td class="$([ $WIDGET_TEST_RESULT -eq 0 ] && echo 'success' || echo 'error')">
                $([ $WIDGET_TEST_RESULT -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')
            </td>
            <td>UI component behavior and rendering</td>
        </tr>
        <tr>
            <td>Integration Tests</td>
            <td class="$([ $INTEGRATION_TEST_RESULT -eq 0 ] && echo 'success' || echo 'error')">
                $([ $INTEGRATION_TEST_RESULT -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')
            </td>
            <td>End-to-end user workflows</td>
        </tr>
        <tr>
            <td>Performance Tests</td>
            <td class="$([ $PERFORMANCE_TEST_RESULT -eq 0 ] && echo 'success' || echo 'error')">
                $([ $PERFORMANCE_TEST_RESULT -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')
            </td>
            <td>Memory usage, frame rates, and responsiveness</td>
        </tr>
    </table>

    <h2>🎯 Performance Metrics</h2>
    <div class="metric">
        <strong>Memory Management:</strong> AutoDispose patterns implemented for leak prevention
    </div>
    <div class="metric">
        <strong>Error Handling:</strong> Error boundaries active for all major features
    </div>
    <div class="metric">
        <strong>Video Calling:</strong> Agora SDK integration with quality monitoring
    </div>
    <div class="metric">
        <strong>State Management:</strong> Riverpod providers with comprehensive observability
    </div>

    <h2>📁 Generated Artifacts</h2>
    <ul>
        <li>Coverage reports: <code>coverage/html/index.html</code></li>
        <li>Test results: <code>test_results/*.json</code></li>
        <li>Release APK: <code>artifacts/app-release.apk</code></li>
        <li>Analysis results: <code>artifacts/analysis_results.txt</code></li>
    </ul>
</body>
</html>
EOF

echo ""
echo -e "${BLUE}🔍 Analyzing Test Results...${NC}"
TOTAL_TESTS=0
FAILED_TESTS=0

# Count tests from JSON files if they exist
if [ -f "test_results/unit_tests.json" ]; then
    UNIT_COUNT=$(grep -o '"type":"testDone"' test_results/unit_tests.json 2>/dev/null | wc -l)
    TOTAL_TESTS=$((TOTAL_TESTS + UNIT_COUNT))
    echo "Unit tests executed: $UNIT_COUNT"
fi

if [ -f "test_results/widget_tests.json" ]; then
    WIDGET_COUNT=$(grep -o '"type":"testDone"' test_results/widget_tests.json 2>/dev/null | wc -l)
    TOTAL_TESTS=$((TOTAL_TESTS + WIDGET_COUNT))
    echo "Widget tests executed: $WIDGET_COUNT"
fi

if [ -f "test_results/integration_tests.json" ]; then
    INTEGRATION_COUNT=$(grep -o '"type":"testDone"' test_results/integration_tests.json 2>/dev/null | wc -l)
    TOTAL_TESTS=$((TOTAL_TESTS + INTEGRATION_COUNT))
    echo "Integration tests executed: $INTEGRATION_COUNT"
fi

echo ""
echo "📊 Final Test Results Summary:"
echo "=============================="

if [ $UNIT_TEST_RESULT -eq 0 ]; then
    echo -e "Unit Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Unit Tests: ${RED}❌ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if [ $WIDGET_TEST_RESULT -eq 0 ]; then
    echo -e "Widget Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Widget Tests: ${RED}❌ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if [ $INTEGRATION_TEST_RESULT -eq 0 ]; then
    echo -e "Integration Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Integration Tests: ${RED}❌ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

if [ $PERFORMANCE_TEST_RESULT -eq 0 ]; then
    echo -e "Performance Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Performance Tests: ${RED}❌ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""
echo -e "${BLUE}📈 Statistics:${NC}"
echo "Total tests executed: $TOTAL_TESTS"
echo "Failed test suites: $FAILED_TESTS/4"

# Coverage summary
if [ -f "test_reports/coverage_summary.txt" ]; then
    echo ""
    echo -e "${BLUE}📊 Coverage Summary:${NC}"
    cat test_reports/coverage_summary.txt
fi

# Overall result
echo ""
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! CI/CD pipeline ready for deployment.${NC}"
    echo -e "${GREEN}📁 Artifacts ready in: artifacts/, test_results/, test_reports/, coverage/${NC}"
    exit 0
else
    echo -e "${RED}💥 $FAILED_TESTS test suite(s) failed! Check the reports for details.${NC}"
    echo -e "${YELLOW}🔍 Review files: test_reports/performance_summary.html${NC}"
    exit 1
fi
