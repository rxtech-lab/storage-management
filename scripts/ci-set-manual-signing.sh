#!/bin/bash
# Temporarily patches the Xcode project to use manual code signing for CI.
# Usage:
#   ./scripts/ci-set-manual-signing.sh <signing_identity> <provisioning_profile_name>
#
# The project.pbxproj is modified in-place. In CI, the repo is a fresh checkout
# so no revert is needed. For local testing, use git checkout to restore.
set -e

SIGNING_IDENTITY="${1:?Usage: $0 <signing_identity> <provisioning_profile_name>}"
PROFILE_NAME="${2:?Usage: $0 <signing_identity> <provisioning_profile_name>}"

PBXPROJ="$(dirname "$0")/../RxStorage/RxStorage.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "Error: project.pbxproj not found at $PBXPROJ"
  exit 1
fi

# Replace Automatic signing with Manual + provisioning profile in the
# RxStorage app target's Release build configuration.
# Uses sed to:
#   1. Change CODE_SIGN_STYLE = Automatic → Manual (in Release section)
#   2. Add PROVISIONING_PROFILE_SPECIFIER and CODE_SIGN_IDENTITY after CODE_SIGN_STYLE
sed -i '' \
  "/DF6625832F29137000333552.*Release/,/name = Release/ {
    s/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/
    /CODE_SIGN_STYLE = Manual/ {
      n
      /PROVISIONING_PROFILE_SPECIFIER/! {
        i\\
\\				CODE_SIGN_IDENTITY = \"${SIGNING_IDENTITY}\";\\
\\				PROVISIONING_PROFILE_SPECIFIER = \"${PROFILE_NAME}\";
      }
    }
  }" "$PBXPROJ"

echo "Patched project.pbxproj for manual signing (identity: $SIGNING_IDENTITY, profile: $PROFILE_NAME)"
