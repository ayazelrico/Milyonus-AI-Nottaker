# P0-03 - Swift foundation

Status: implementation authorized by the owner on 2026-10-02.

## Goal and requirements

Establish a macOS 14+ Swift 6 package that builds with Command Line Tools, exposes service contracts through Shared, and runs a native SwiftUI application. Covers FR-01 native shell, FR-02 English/Turkish UI, and NFR-01 module isolation from the reconstructed PRD.

## Plan

1. Add Shared, DesignSystem, and MilyonusApp targets. Introduce feature targets only when they own behavior, rather than empty placeholder modules.
2. Define Sendable models and protocols for audio, transcription, language generation, embeddings, meeting storage, calendar, authentication, and billing in Shared.
3. Add deterministic tests for model invariants, localization fallback, and meeting state behavior. No cloud or capture calls are made by the foundation.
4. Store English/Turkish strings in String Catalogs. Generate standard localized resources with a repository-owned script so plain SwiftPM builds work without an Xcode project.
5. Validate build, tests, module imports, and resources in the final app bundle.

## Boundaries and edge cases

Shared has no UI or provider dependencies. DesignSystem may import Shared; MilyonusApp is the composition root. Future features may import Shared and DesignSystem only. Missing translations fall back to English. Invalid or unavailable service state must never appear connected. Strict concurrency remains enabled.

## Risks

Catalog compilation and resource bundling require a runtime smoke test. macOS 14 availability must be retained despite a newer development SDK. External credentials are never embedded.
