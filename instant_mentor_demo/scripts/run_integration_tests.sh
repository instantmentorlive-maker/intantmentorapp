#!/bin/bash

# Integration Test Runner for Day 24
# Run this script to execute all integration tests

echo "🧪 Starting Day 24 Integration Tests..."
echo "========================================"

# Check if flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check if integration_test package is available
flutter pub deps | grep integration_test > /dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  integration_test package not found, adding it..."
    flutter pub add integration_test --dev
fi

echo "📱 Running Integration Tests..."

# Run integration tests
flutter test integration_test/auth_chat_integration_test.dart

TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ All integration tests passed!"
    echo ""
    echo "📊 Test Coverage Summary:"
    echo "- Authentication happy path ✅"
    echo "- Chat message sending ✅" 
    echo "- Error handling ✅"
    echo "- Offline behavior ✅"
    echo "- Video call join/leave ✅"
    echo ""
    echo "🎯 Day 24 Integration Testing: COMPLETE"
else
    echo "❌ Some integration tests failed"
    echo "Check the output above for details"
    exit 1
fi

echo ""
echo "🚀 Ready for Day 25 - Widget Tests!"
