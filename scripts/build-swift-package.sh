#!/bin/bash
# Build RxStorageCore Swift package directly

cd /Users/qiweili/Desktop/rxlab/storage-management/RxStorage/packages/RxStorageCore

# Clean and build
rm -rf .build
swift build --disable-sandbox 2>&1
