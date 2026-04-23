#!/usr/bin/env bash
# Verifies that the Planner app target compiles cleanly in Release configuration
# for macOS and iOS/iPadOS. Code signing is disabled so the check runs on any
# machine (including CI runners without provisioning profiles).

set -euo pipefail

PROJECT="Planner.xcodeproj"
SCHEME="Planner"
CONFIGURATION="Release"

cd "$(dirname "$0")/.."

build_for_platform() {
  local platform="$1"
  echo
  echo "=== Release build: ${platform} ==="
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=${platform}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build
}

build_for_platform "macOS"
build_for_platform "iOS"

echo
echo "Release build OK for macOS and iOS."
