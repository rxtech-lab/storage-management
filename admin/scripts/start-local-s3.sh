#!/usr/bin/env bash
set -e

# Start local S3 server using s3rver
# This script starts a local S3-compatible server for development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
S3_DATA_DIR="$PROJECT_ROOT/.local-s3"
S3_PORT="${LOCAL_S3_PORT:-4569}"

echo "Starting local S3 server..."
echo "Data directory: $S3_DATA_DIR"
echo "Port: $S3_PORT"

# Create data directory if it doesn't exist
mkdir -p "$S3_DATA_DIR"

# Start s3rver
# --directory: Where to store S3 data
# --port: Port to listen on (default 4569)
# --address: Bind to localhost
exec npx s3rver \
  --directory "$S3_DATA_DIR" \
  --port "$S3_PORT" \
  --address localhost \
  --silent false
