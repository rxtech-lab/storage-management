#!/bin/bash

# Script to decode base64-encoded RXSTORAGE_TESTING_SECRETS and write to RxStorage/.env

set -e

# Get the repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/RxStorage/.env"

# Check if RXSTORAGE_TESTING_SECRETS is set
if [ -z "$RXSTORAGE_TESTING_SECRETS" ]; then
    echo "Error: RXSTORAGE_TESTING_SECRETS environment variable is not set"
    exit 1
fi

# Decode base64 and write to .env file
echo "$RXSTORAGE_TESTING_SECRETS" | base64 --decode > "$OUTPUT_FILE"

echo "Successfully decoded secrets to $OUTPUT_FILE"
