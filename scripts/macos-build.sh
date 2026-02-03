#!/bin/bash

# macOS Build Script for RxStorage

set -e

PROJECT_PATH="RxStorage/RxStorage.xcodeproj"
SCHEME="RxStorage"
CONFIGURATION="Debug"
DESTINATION="platform=macOS,arch=arm64"

echo "Building RxStorage for macOS..."

xcodebuild build \
    -project "$PROJECT_PATH" \
    -target "RxStorage" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES \
    SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO \
    2>&1 | tee build-macos.log

BUILD_EXIT_CODE=${PIPESTATUS[0]}

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "✅ Build succeeded!"
    exit 0
else
    echo "❌ Build failed! Check build-macos.log for details"
    exit 1
fi
