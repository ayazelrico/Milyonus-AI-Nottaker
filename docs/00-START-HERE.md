# 00 - Start here

The foundation uses SwiftPM and terminal tools. Xcode's IDE is optional. Full Xcode is needed only
when a required Apple tool or SDK is unavailable through Command Line Tools; report the exact failure
before asking the owner to change their setup. This repository targets macOS 14 or newer.

## Local workflow

1. Read AGENTS.md, then PRD, architecture, decisions, and the current task spec.
2. Approve installation before running scripts/install-swift-tools.sh or pnpm install.
3. Generate resources: `python3 scripts/generate-localizations.py`.
4. Build and test: `swift build --package-path app` and `bash scripts/test-swift.sh`.
5. Bundle: `bash scripts/bundle-app.sh debug`.
6. Launch: `open "build/Milyonus Nottaker.app"`.
7. Run the backend from backend/ using `pnpm dev`; see docs/12 for configuration.
8. Run `bash scripts/check.sh` before committing.

No provider account or audio permission is required to inspect the sample workspace. It never
records, uploads, or generates AI output. Backend auth remains fail-closed until configured.

## Signing

The default bundle uses ad hoc signing for local preview. Set MILYONUS_SIGNING_IDENTITY to an
available stable identity for permission persistence tests. Do not paste signing keys or export
certificates into this repository. Developer ID/notarization is a later distribution requirement.

## Build order

P0-01 repository -> P0-03 Swift -> P0-04 backend -> P0-05 bundle. UI/Gallery and CI are built alongside
these foundations. P0-02 accounts, P0-06 cloud schema, P0-07 live sign-in, and P0-10 legal decisions
depend on external setup. A local preview does not mark all of Phase 0 complete.

The owner authorized reconstructing missing plans and proceeding on 2026-10-02. Work in small,
verified changes with specs and meaningful tests. Further routine plan/commit approvals are not
required for this authorized work. Installations and external resources follow AGENTS.md.
