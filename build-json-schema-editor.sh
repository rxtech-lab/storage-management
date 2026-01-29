#!/bin/bash
cd RxStorage/packages/JsonSchemaEditor
rm -rf .build 2>/dev/null
swift build 2>&1 | head -100
