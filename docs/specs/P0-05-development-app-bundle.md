# P0-05 - Development app bundle

Status: implementation authorized by the owner on 2026-10-02.

## Goal and requirements

Build a launchable macOS application from SwiftPM with packaged resources, stable bundle identifier, menu bar presence, and explicit signing status. Covers FR-01 and NFR-05 distribution identity.

## Plan

1. Build release/debug output through SwiftPM and copy the executable and resource bundles into build/Milyonus Nottaker.app.
2. Supply Info.plist, microphone usage description, development entitlements, and generated native icon resources.
3. Sign with a configured identity when available. Allow explicitly labeled ad hoc local preview while keeping persistent-TCC acceptance pending until stable signing is verified.
4. Launch and inspect the app, Gallery, navigation, sample meeting, settings, English/Turkish switching, and packaged resources.

## Edge cases and verification

Bundle scripts reject unsafe paths and do not require global Xcode selection for pure SwiftPM builds. No recording or permission prompt happens on launch. No signing keys are read or committed. Signing verification and local preview do not imply notarization or stable privacy permission persistence. Test rebuild behavior only after a persistent identity is selected.
