#!/bin/bash
# Regenerate admin/public/openapi.json and copy it to the iOS and CLI packages
# without needing a running server (the committed spec points at localhost:3000).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/admin"
bun run openapi:generate
cd "$ROOT"
python3 - <<'PY'
import json
spec = json.load(open("admin/public/openapi.json"))
spec["servers"] = [{"url": "http://localhost:3000", "description": "Current server"}]
out = json.dumps(spec, indent=2) + "\n"
for target in ("RxStorage/packages/RxStorageCore/Sources/RxStorageCore/openapi.json",
               "cli/RxStorageCli/Sources/RxStorageCli/openapi.json"):
    open(target, "w").write(out)
    print("updated", target)
PY
