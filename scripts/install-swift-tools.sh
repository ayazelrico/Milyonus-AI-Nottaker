#!/bin/bash
set -euo pipefail

# Run only after approving development-tool installation. All files stay in this repository.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_DIR/.tools"
mkdir -p "$TOOLS_DIR/downloads" "$TOOLS_DIR/bin"

install_binary() {
  local name="$1" version="$2" url="$3" checksum="$4"
  local archive="$TOOLS_DIR/downloads/$name-$version.zip"
  local target="$TOOLS_DIR/$name-$version"
  if [[ -x "$target/$name" ]]; then
    ln -sfn "../$name-$version/$name" "$TOOLS_DIR/bin/$name"
    return
  fi
  curl --fail --location --proto '=https' --tlsv1.2 "$url" --output "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 --check
  mkdir -p "$target"
  /usr/bin/ditto -x -k "$archive" "$target"
  test -f "$target/$name"
  chmod +x "$target/$name"
  ln -sfn "../$name-$version/$name" "$TOOLS_DIR/bin/$name"
}

install_binary swiftlint 0.65.1 \
  https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip \
  c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
install_binary swiftformat 0.63.1 \
  https://github.com/nicklockwood/SwiftFormat/releases/download/0.63.1/swiftformat.zip \
  385ef1a263ba28685157b98c5536b9c9105e124518f28b7ef8a2bee4b167eaeb

"$TOOLS_DIR/bin/swiftlint" version
"$TOOLS_DIR/bin/swiftformat" --version
