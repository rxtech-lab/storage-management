#!/bin/bash

# Admin E2E Test Script
# Runs Playwright E2E tests for the admin app

set -e  # Exit on error

echo "======================================"
echo "Admin E2E Test Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Navigate to admin directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ADMIN_DIR="$SCRIPT_DIR/../admin"

if [ ! -d "$ADMIN_DIR" ]; then
    echo -e "${RED}Error: admin directory not found at $ADMIN_DIR${NC}"
    exit 1
fi

cd "$ADMIN_DIR"

echo "Running E2E tests from: $(pwd)"
echo ""

# Run e2e tests
if bun run test:e2e; then
    echo ""
    echo -e "${GREEN}E2E tests completed successfully!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}E2E tests failed!${NC}"
    exit 1
fi
