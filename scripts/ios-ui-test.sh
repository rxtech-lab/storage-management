#!/bin/bash

# iOS UI Test Script for CI/CD
# Runs UI tests for the RxStorage iOS app

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

echo "======================================"
echo "RxStorage iOS UI Test Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_PATH="RxStorage/RxStorage.xcodeproj"
SCHEME="${SCHEME:-RxStorage}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-iphonesimulator}"
BUILD_DIR="${BUILD_DIR:-.build}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-ui-test-results.xcresult}"
LOG_FILE="${LOG_FILE:-ui-test.log}"

# Find an available iOS simulator if DESTINATION is not set
if [ -z "$DESTINATION" ]; then
    # First, check if there's already a booted simulator we can reuse
    echo "🔍 Checking for running simulators..."
    BOOTED_UDID=$(xcrun simctl list devices booted --json | jq -r '.devices | to_entries | .[] | .value[] | .udid' | head -1)

    if [ -n "$BOOTED_UDID" ]; then
        DESTINATION="platform=iOS Simulator,id=$BOOTED_UDID"
        BOOTED_NAME=$(xcrun simctl list devices booted --json | jq -r '.devices | to_entries | .[] | .value[] | .name' | head -1)
        echo -e "${GREEN}📱 Reusing running simulator: $BOOTED_NAME ($BOOTED_UDID)${NC}"
    else
        echo "🔍 No running simulator found, finding available one..."
        SIMULATOR_NAME=$(xcrun simctl list devices available --json | jq -r '.devices | to_entries | .[] | select(.key | contains("iOS")) | .value[] | select(.isAvailable == true) | .name' | head -1)

        if [ -z "$SIMULATOR_NAME" ]; then
            echo -e "${RED}❌ Error: No available iOS simulator found${NC}"
            echo "Please install an iOS simulator via Xcode > Settings > Platforms"
            exit 1
        fi

        DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest"
        echo "📱 Auto-detected simulator: $SIMULATOR_NAME"
    fi
fi

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Error: $PROJECT_PATH not found${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if Secrets.xcconfig exists
SECRETS_CONFIG="RxStorage/RxStorage/Config/Secrets.xcconfig"
if [ ! -f "$SECRETS_CONFIG" ]; then
    echo -e "${YELLOW}⚠️  Warning: $SECRETS_CONFIG not found${NC}"
    echo "This file should be created from GitHub secrets in CI or manually for local builds."
fi

# Check if .env file exists for test credentials
ENV_FILE="RxStorage/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✅ Found .env file for test credentials${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: $ENV_FILE not found${NC}"
    echo "UI tests will read credentials from .env file."
    echo "Create one from the example:"
    echo "  cp RxStorage/.env.example RxStorage/.env"
    echo "  # Then edit with your test credentials"
    echo ""
fi

echo -e "${BLUE}📦 Project:${NC} $PROJECT_PATH"
echo -e "${BLUE}🎯 Scheme:${NC} $SCHEME"
echo -e "${BLUE}⚙️  Configuration:${NC} $CONFIGURATION"
echo -e "${BLUE}📱 SDK:${NC} $SDK"
echo -e "${BLUE}🎯 Destination:${NC} $DESTINATION"
echo -e "${BLUE}📂 Build Directory:${NC} $BUILD_DIR"
echo -e "${BLUE}📊 Result Bundle:${NC} $RESULT_BUNDLE_PATH"
echo -e "${BLUE}📝 Log File:${NC} $LOG_FILE"
echo ""

# Clean previous test results
echo "🧹 Cleaning previous test results..."
rm -rf "$RESULT_BUNDLE_PATH"
rm -f "$LOG_FILE"

echo ""

# Build and run UI tests in one step
echo "🔨 Building and running UI tests..."
echo ""
echo "📱 This will build the app, boot the simulator, and run tests."
echo "⏱️  This may take several minutes. Logs will appear as tests run."
echo ""

set +e  # Temporarily disable exit on error to capture the exit code

# Use xcbeautify for pretty printing if available, otherwise raw output
if command -v xcbeautify &> /dev/null; then
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -testPlan TestPlan \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -parallel-testing-enabled NO \
        -skipPackagePluginValidation \
        2>&1 | tee "$LOG_FILE" | xcbeautify
    TEST_EXIT_CODE=${PIPESTATUS[0]}
else
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -testPlan TestPlan \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$BUILD_DIR" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -parallel-testing-enabled NO \
        -skipPackagePluginValidation \
        2>&1 | tee "$LOG_FILE"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
fi

set -e  # Re-enable exit on error

echo ""
echo "======================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All UI tests passed!${NC}"
    echo ""
    echo "Test log saved to: $LOG_FILE"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"

    # Extract and display test logs from result bundle
    if command -v xcrun &> /dev/null && [ -d "$RESULT_BUNDLE_PATH" ]; then
        echo ""
        echo "📝 Test Logs (NSLog output):"
        echo "======================================"

        # Extract standard output which contains NSLog statements
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" 2>/dev/null | \
            grep -E "🔐|⏱️|✅|❌|Safari|field|password|email|sign-in" || \
            echo "No NSLog statements found in test output"

        echo ""
        echo "Full test output saved to: ui-test-details.log"
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" > ui-test-details.log 2>&1 || true
    fi

    exit 0
else
    echo -e "${RED}❌ UI tests failed!${NC}"
    echo ""
    echo "Test log saved to: $LOG_FILE"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"

    # Extract and display test logs from result bundle on failure
    if command -v xcrun &> /dev/null && [ -d "$RESULT_BUNDLE_PATH" ]; then
        echo ""
        echo "📝 Test Logs (NSLog output):"
        echo "======================================"

        # Extract standard output which contains NSLog statements
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" 2>/dev/null | \
            grep -E "🔐|⏱️|✅|❌|Safari|field|password|email|sign-in" || \
            echo "No NSLog statements found in test output"

        echo ""
        echo "Full test output saved to: ui-test-details.log"
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" > ui-test-details.log 2>&1 || true
    fi

    echo ""
    echo "Common issues:"
    echo "1. Check test failures in the log above"
    echo "2. Verify backend server is running at http://localhost:3000"
    echo "3. Ensure RxStorage/.env has TEST_EMAIL and TEST_PASSWORD set"
    echo "4. Check if simulator is booted and accessible"
    echo "5. Review OAuth configuration in Secrets.xcconfig"
    echo ""
    echo "See $LOG_FILE for full error details"
    exit 1
fi
