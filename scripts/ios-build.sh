#!/bin/bash

# iOS Build Script for CI/CD
# Builds the RxStorage iOS app

set -e  # Exit on error
set -o pipefail  # Catch errors in pipes

echo "======================================"
echo "RxStorage iOS Build Script"
echo "======================================"
echo ""

# Configuration
PROJECT_PATH="RxStorage/RxStorage.xcodeproj"
SCHEME="${SCHEME:-RxStorage}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SDK="${SDK:-iphonesimulator}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 15,OS=latest}"
BUILD_DIR="${BUILD_DIR:-.build}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
echo ""

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    > /dev/null 2>&1 || true

echo ""

# Build the project
echo "🔨 Building project..."
echo ""

xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee build.log \
    | xcbeautify || cat build.log

# Check build result
BUILD_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "======================================"

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    echo ""
    echo "Build log saved to: build.log"
    exit 0
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Build log saved to: build.log"
    echo ""
    echo "Common issues:"
    echo "1. Check if RxStorageCore package is added to the project"
    echo "2. Verify Info.plist configuration"
    echo "3. Check if .xcconfig files are properly assigned"
    echo "4. Ensure Secrets.xcconfig is present and properly formatted"
    echo ""
    echo "See build.log for full error details"
    exit 1
fi
