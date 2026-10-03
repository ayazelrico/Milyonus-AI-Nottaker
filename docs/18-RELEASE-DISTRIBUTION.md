# 18 - Bundling and release distribution

The foundation creates build/Milyonus Nottaker.app through scripts/bundle-app.sh. It includes
Info.plist, executable, package resource bundles, localized permission text, and a native icon.
The stable development bundle identifier is com.milyonus.nottaker.dev. Release identity/versioning
must be finalized before public distribution.

Default signing is ad hoc for local preview, clearly reported by the script. A valid signature is
not equivalent to notarization or stable TCC identity. Select a persistent signing identity through
MILYONUS_SIGNING_IDENTITY; never add certificates/private keys to Git. Test permissions across two
rebuilds and launches before marking P0-05 complete.

The release configuration removes debug Gallery access. It is still a foundation preview, not a
shippable product. Phase 7 requires Developer ID, Hardened Runtime review, notarization/stapling,
DMG creation, Sparkle signed updates, rollback, clean-machine testing, and an approved release plan.
Do not make distribution claims based on local codesign verification alone.
