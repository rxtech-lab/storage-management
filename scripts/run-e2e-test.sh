#!/bin/bash
cd /Users/qiweili/Desktop/rxlab/storage-management/admin
IS_E2E=true bunx playwright test --grep "Items API" 2>&1
