#!/bin/bash
# Wrapper script to build iOS app from repository root
pushd /Users/qiweili/Desktop/rxlab/storage-management/RxStorage > /dev/null
./build.sh "$@"
popd > /dev/null
