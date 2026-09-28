#!/bin/bash
# Run admin Playwright e2e tests. Pass spec paths to run a subset, e.g.
#   ./scripts/admin-e2e.sh e2e/api/iso-jobs.spec.ts
set -e
cd "$(dirname "$0")/../admin"
IS_E2E=true bunx playwright test "$@"
