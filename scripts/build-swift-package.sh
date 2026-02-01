#!/bin/bash
# Build RxStorageCore Swift package directly

cd /Users/qiweili/Desktop/rxlab/storage-management/RxStorage/packages/RxStorageCore

# Clean and build
rm -rf .build
swift build 2>&1
