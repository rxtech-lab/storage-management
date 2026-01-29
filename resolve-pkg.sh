#!/bin/bash
cd RxStorage/packages/JsonSchemaEditor
swift package resolve
find .build -name "ObjectSchema.swift" -o -name "ArraySchema.swift" -o -name "JSONSchema.swift" 2>/dev/null | head -20
