#!/bin/bash
set -e
cd "$(dirname "$0")/../admin"
bun run build
