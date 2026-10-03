# 17 - Development setup

Use any editor, including VS Code. SwiftPM owns package structure; no Xcode project is required for
the current foundation. The optional Xcode IDE should not become the primary workflow by accident.

## Prerequisites

- macOS 14+ and Swift 6 Command Line Tools or a compatible Xcode toolchain.
- Node version from .node-version for CI consistency; backend package declares compatible engines.
- pnpm version pinned in backend/package.json.
- SwiftLint/SwiftFormat from scripts/install-swift-tools.sh after installation approval. Tools and
  download caches stay under .tools/ in this repository, with SHA-256 verification.

## Commands

```sh
python3 scripts/generate-localizations.py
swift build --package-path app
bash scripts/test-swift.sh
bash scripts/bundle-app.sh debug
open "build/Milyonus Nottaker.app"
pnpm --dir backend install --frozen-lockfile
pnpm --dir backend dev
bash scripts/check.sh
```

Do not read secrets to diagnose setup. Configure backend/.env.local privately, using the empty
.env.example variable names and docs/12. A public local health endpoint works without cloud keys;
protected endpoints fail closed until auth is configured.

## When Xcode is necessary

Recent Command Line Tools ship Swift Testing but do not put its framework on SwiftPM's default
search path. scripts/test-swift.sh supplies test-only framework/runtime paths for that toolchain.
It invokes ordinary swift test under full Xcode. No extra package or global setting is needed.
scripts/check.sh and bundle-app.sh rebuild with normal flags after tests so test runtime paths are
not carried into the packaged app. Older toolchains without Testing.framework require an update.

Check xcode-select -p and the exact missing command. A Command Line Tools directory does not provide
xcodebuild. Do not run xcode-select --install to select full Xcode. When needed, install/open Xcode,
accept the license, and select its developer directory with the owner's approval. Do not perform
global developer-directory changes silently. Certificate/account setup may use Xcode when necessary.

The current String Catalog generator compiles simple stringUnit entries into .strings resources.
Unsupported catalog structures fail explicitly. Plural/substitution support needs a tested extension
or Xcode-backed compilation before those structures are introduced.
