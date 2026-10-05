#!/bin/bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$REPO_DIR/.tools/bin:$PATH"
cd "$REPO_DIR"

python3 scripts/generate-localizations.py --check
python3 scripts/check-repository.py
bash scripts/test-swift.sh
# Restore ordinary application link settings after test-only toolchain search paths.
swift build --package-path app -Xswiftc -warnings-as-errors
DEVELOPER_DIRECTORY="$(xcode-select -p)"
if [[ "$DEVELOPER_DIRECTORY" == "/Library/Developer/CommandLineTools" ]]; then
  DYLD_FRAMEWORK_PATH="$DEVELOPER_DIRECTORY/usr/lib" swiftlint lint --strict --config .swiftlint.yml
else
  swiftlint lint --strict --config .swiftlint.yml
fi
swiftformat app --lint --config .swiftformat
pnpm --dir backend build
pnpm --dir backend test
pnpm --dir backend lint
