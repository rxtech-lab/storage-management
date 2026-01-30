#!/bin/bash

# iOS Test Script for CI/CD
# Runs tests for the RxStorage iOS app

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

echo "======================================"
echo "RxStorage iOS Test Script"
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
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-test-results.xcresult}"

# Find an available iOS simulator if DESTINATION is not set
if [ -z "$DESTINATION" ]; then
    echo "🔍 Finding available iOS simulator..."
    SIMULATOR_NAME=$(xcrun simctl list devices available --json | jq -r '.devices | to_entries | .[] | select(.key | contains("iOS")) | .value[] | select(.isAvailable == true) | .name' | head -1)

    if [ -z "$SIMULATOR_NAME" ]; then
        echo -e "${RED}❌ Error: No available iOS simulator found${NC}"
        echo "Please install an iOS simulator via Xcode > Settings > Platforms"
        exit 1
    fi

    DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest"
    echo "📱 Auto-detected simulator: $SIMULATOR_NAME"
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

echo -e "${BLUE}📦 Project:${NC} $PROJECT_PATH"
echo -e "${BLUE}🎯 Scheme:${NC} $SCHEME"
echo -e "${BLUE}⚙️  Configuration:${NC} $CONFIGURATION"
echo -e "${BLUE}📱 SDK:${NC} $SDK"
echo -e "${BLUE}🎯 Destination:${NC} $DESTINATION"
echo -e "${BLUE}📂 Build Directory:${NC} $BUILD_DIR"
echo -e "${BLUE}📊 Result Bundle:${NC} $RESULT_BUNDLE_PATH"
echo ""

# Clean previous test results
echo "🧹 Cleaning previous test results..."
rm -rf "$RESULT_BUNDLE_PATH"

echo ""

# Run Swift Package tests
echo "🧪 Running Swift Package tests..."
echo ""

PACKAGES_DIR="RxStorage/packages"
PACKAGE_TEST_FAILED=0

for package_dir in "$PACKAGES_DIR"/*/; do
    if [ -f "${package_dir}Package.swift" ]; then
        package_name=$(basename "$package_dir")
        echo -e "${BLUE}📦 Testing package: ${package_name}${NC}"

        if swift test --package-path "$package_dir"; then
            echo -e "${GREEN}✅ ${package_name} tests passed${NC}"
        else
            echo -e "${RED}❌ ${package_name} tests failed${NC}"
            PACKAGE_TEST_FAILED=1
        fi
        echo ""
    fi
done

if [ $PACKAGE_TEST_FAILED -ne 0 ]; then
    echo -e "${RED}❌ One or more Swift Package tests failed!${NC}"
    exit 1
fi

echo ""

# Run tests
echo "🧪 Running xcodebuild tests..."
echo ""

# Run xcodebuild and capture exit code properly
set +e  # Temporarily disable exit on error to capture the exit code
xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$BUILD_DIR" \
    -resultBundlePath "$RESULT_BUNDLE_PATH" \
    -skip-testing:RxStorageUITests \
    -enableCodeCoverage YES \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee test.log
TEST_EXIT_CODE=${PIPESTATUS[0]}
set -e  # Re-enable exit on error

# Pretty print if xcbeautify is available, otherwise show raw output
if command -v xcbeautify &> /dev/null && [ -f test.log ]; then
    cat test.log | xcbeautify || true
fi

echo ""
echo "======================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Test log saved to: test.log"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"

    # Display test summary if xcresult is available
    if command -v xcrun &> /dev/null && [ -d "$RESULT_BUNDLE_PATH" ]; then
        echo ""
        echo "📊 Test Summary:"
        xcrun xcresulttool get --format json --path "$RESULT_BUNDLE_PATH" > /dev/null 2>&1 || true
    fi

    exit 0
else
    echo -e "${RED}❌ Tests failed!${NC}"
    echo ""
    echo "Test log saved to: test.log"
    echo "Result bundle saved to: $RESULT_BUNDLE_PATH"
    echo ""
    echo "Common issues:"
    echo "1. Check test failures in the log above"
    echo "2. Verify simulator is available and booted"
    echo "3. Check if RxStorageCore package tests are failing"
    echo "4. Ensure Secrets.xcconfig is present with valid values"
    echo ""
    echo "See test.log for full error details"
    exit 1
fi
