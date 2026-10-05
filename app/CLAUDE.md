# App implementation guide

Read [../AGENTS.md](../AGENTS.md) first. The root file owns repository rules.

The app is a macOS 14+ Swift 6 package. `Shared` owns Sendable domain values and external-service
protocols. `DesignSystem` owns visual tokens and components. `MilyonusApp` is the composition root.
Add feature targets only when they have real behavior; keep service implementations behind Shared
protocols. Enable strict concurrency through Swift 6 language mode. Persistence owns encrypted GRDB
transcript storage and backend outbox synchronization.

Use `AppStrings.text(_:language:)` for visible copy. English is the default. Add English and Turkish
strings to `Sources/Shared/Resources/Localizable.xcstrings`, then run
`python3 ../scripts/generate-localizations.py` from `app/`. Generated `.strings` files are committed
and checked for drift so `swift build` works without an Xcode project. Native usage descriptions
have a separate source catalog at `Support/InfoPlist.xcstrings`, handled by the same generator.

Run `swift build` and `swift test` from this directory. The repository verification script owns
lint and format checks. Use the bundled `.app` for native permission and resource verification;
running a bare SwiftPM executable is not evidence that macOS permission behavior is correct.

The workspace displays clearly labeled sample content. Authentication lives in its own target and
uses Supabase PKCE plus Keychain. AudioCapture, Permissions, and Transcription own tested native
services, and the live meeting UI accepts injected mixer and transcription services. The default
preview keeps recording unavailable until consent and runtime service wiring are complete.
