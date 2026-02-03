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

        if swift test --package-path "$package_dir" --disable-sandbox; then
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

# Swift Package tests are the primary unit tests for this project.
# The Xcode project only contains UI tests (RxStorageUITests), not unit tests.
# Unit tests live in the Swift packages (RxStorageCore, JsonSchemaEditor).

echo ""
echo "======================================"
echo -e "${GREEN}✅ All unit tests passed!${NC}"
echo ""
echo "Note: Unit tests are run via Swift Package Manager (above)."
echo "UI tests can be run separately with: ./scripts/ios-ui-test.sh"
exit 0
