#!/bin/bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"

# Recent Command Line Tools ship Swift Testing without adding it to SwiftPM's default search path.
# Supply test-only framework/runtime paths without requiring Xcode or changing global settings.
if [[ "$DEVELOPER_PATH" == */CommandLineTools ]]; then
  FRAMEWORKS="$DEVELOPER_PATH/Library/Developer/Frameworks"
  TEST_LIBRARIES="$DEVELOPER_PATH/Library/Developer/usr/lib"
  if [[ ! -d "$FRAMEWORKS/Testing.framework" ]]; then
    printf 'This Command Line Tools installation lacks Swift Testing. Use a compatible Xcode toolchain.\n' >&2
    exit 1
  fi
  swift test --package-path "$REPO_DIR/app" --disable-xctest \
    -Xswiftc -warnings-as-errors \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$TEST_LIBRARIES" "$@"
else
  swift test --package-path "$REPO_DIR/app" -Xswiftc -warnings-as-errors "$@"
fi
