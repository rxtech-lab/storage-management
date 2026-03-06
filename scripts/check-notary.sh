#!/bin/bash
set -euo pipefail

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_ID_PWD:?APPLE_ID_PWD is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

NOTARIZATION_ID="${1:-}"

if [ -z "$NOTARIZATION_ID" ]; then
  echo "Usage: $0 <notarization-id>"
  exit 1
fi

xcrun notarytool log "$NOTARIZATION_ID" \
  --output-format json \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_ID_PWD"
