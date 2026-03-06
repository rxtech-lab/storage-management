#!/bin/bash
# Update OpenAPI spec for iOS (RxStorageCore) and CLI (RxStorageCli) packages
# Default: https://storage.rxlab.app/api/openapi
# Override: Set OPENAPI_DOCUMENTATION_ENDPOINT environment variable
# Example for local dev: OPENAPI_DOCUMENTATION_ENDPOINT=http://localhost:3000/api/openapi ./scripts/ios-update-openapi.sh

set -e

cd ./admin
bun run openapi:generate

cd ../

IOS_TARGET="./RxStorage/packages/RxStorageCore/Sources/RxStorageCore/openapi.json"
CLI_TARGET="./cli/RxStorageCli/Sources/RxStorageCli/openapi.json"

ENDPOINT="${OPENAPI_DOCUMENTATION_ENDPOINT:-http://localhost:3000/api/openapi}"

echo "Downloading OpenAPI spec from: $ENDPOINT"
curl -sS -o "$IOS_TARGET" "$ENDPOINT"

# Validate that the downloaded file is valid JSON
echo "Validating JSON..."
if ! python3 -m json.tool "$IOS_TARGET" > /dev/null 2>&1; then
    echo "Error: Downloaded file is not valid JSON"
    echo "Contents of $IOS_TARGET:"
    head -20 "$IOS_TARGET"
    exit 1
fi

# Copy spec to CLI target
cp "$IOS_TARGET" "$CLI_TARGET"

echo "OpenAPI spec updated at:"
echo "  - $IOS_TARGET"
echo "  - $CLI_TARGET"
