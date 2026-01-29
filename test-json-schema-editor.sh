#!/bin/bash

# Test script for JsonSchemaEditor Swift package

set -e

echo "Testing JsonSchemaEditor package..."
cd RxStorage/packages/JsonSchemaEditor
swift test

echo ""
echo "Tests completed successfully!"
