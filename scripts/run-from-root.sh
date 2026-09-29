#!/bin/bash
# Runs the given command from the repository root
cd "$(dirname "$0")/.." && exec "$@"
