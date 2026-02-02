#!/bin/bash
# Update OpenAPI spec for RxStorageCore iOS package
# Default: https://storage.rxlab.app/api/openapi
# Override: Set OPENAPI_DOCUMENTATION_ENDPOINT environment variable
# Example for local dev: OPENAPI_DOCUMENTATION_ENDPOINT=http://localhost:3000/api/openapi ./scripts/ios-update-openapi.sh

set -e

cd ./admin
bun run openapi:generate

cd ../

TARGET_FILE="./RxStorage/packages/RxStorageCore/Sources/RxStorageCore/openapi.json"

ENDPOINT="${OPENAPI_DOCUMENTATION_ENDPOINT:-http://localhost:3000/api/openapi}"

echo "Downloading OpenAPI spec from: $ENDPOINT"
curl -sS -o "$TARGET_FILE" "$ENDPOINT"

# Validate that the downloaded file is valid JSON
echo "Validating JSON..."
if ! python3 -m json.tool "$TARGET_FILE" > /dev/null 2>&1; then
    echo "Error: Downloaded file is not valid JSON"
    echo "Contents of $TARGET_FILE:"
    head -20 "$TARGET_FILE"
    exit 1
fi

echo "OpenAPI spec updated at: $TARGET_FILE"
