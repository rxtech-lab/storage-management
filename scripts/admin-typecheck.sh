#!/bin/bash
# Type-check the admin app without building it.
set -e
cd "$(dirname "$0")/../admin"
bunx tsc --noEmit -p tsconfig.json
