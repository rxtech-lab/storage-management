#!/bin/bash
# Run admin vitest for the given file pattern(s).
cd "$(dirname "$0")/../admin" && bunx vitest run "$@"
