#!/bin/bash

# Xcode Cloud CI script - runs after repository checkout
# Mirrors the setup from .github/workflows/ios-setup.yml

set -e

echo "Running post-clone CI script..."

# Enable automatic trust for Swift Package plugins (required for OpenAPIGenerator)
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatableWarning -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Version bump from tag
if [ -n "$CI_TAG" ]; then
    VERSION="${CI_TAG#v}"   # v1.2.3 → 1.2.3
    echo "Setting MARKETING_VERSION=$VERSION, CURRENT_PROJECT_VERSION=$CI_BUILD_NUMBER"
    cd "$REPO_ROOT/RxStorage"
    # agvtool new-marketing-version only updates Info.plist, not the MARKETING_VERSION
    # build setting. With GENERATE_INFOPLIST_FILE=YES, Xcode uses the build setting,
    # so we must update it directly in the project file.
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" RxStorage.xcodeproj/project.pbxproj
    agvtool new-version -all "$CI_BUILD_NUMBER"
    cd "$REPO_ROOT"
fi

# 1. Setup Secrets.xcconfig from Xcode Cloud environment variable
SECRETS_FILE="$REPO_ROOT/RxStorage/RxStorage/Config/Secrets.xcconfig"
if [ -z "$SECRETS_XCCONFIG_BASE64" ]; then
    echo "❌ Error: SECRETS_XCCONFIG_BASE64 is not set"
    echo "Please configure the SECRETS_XCCONFIG_BASE64 environment variable in Xcode Cloud"
    exit 1
else
    echo "✅ Decoding Secrets.xcconfig from environment"
    echo "Writing to: $SECRETS_FILE"
    echo "$SECRETS_XCCONFIG_BASE64" | base64 --decode > "$SECRETS_FILE"
    echo "Contents of Secrets.xcconfig (with secrets masked):"
    sed 's/\(AUTH_CLIENT_ID.*=\).*/\1 ***/' "$SECRETS_FILE"
fi

# 2. Decode testing secrets (.env file)
"$REPO_ROOT/scripts/decode-env-secrets.sh"

# 3. Install Bun
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# 4. Install dependencies and start dev server
echo "Starting backend server..."
cd "$REPO_ROOT/admin"
bun install
bun dev:e2e &

# 5. Wait for backend server to be ready
echo "Waiting for backend server..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null; then
        echo "✅ Backend server is up!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend server did not start in time"
        exit 1
    fi
    sleep 2
done

# 6. Run OpenAPI update script
echo "Generating OpenAPI client..."
cd "$REPO_ROOT"
./scripts/ios-update-openapi.sh

echo "✅ Post-clone CI script completed"
