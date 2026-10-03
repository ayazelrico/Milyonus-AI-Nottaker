# 03 - Architecture decisions

Reconstructed on 2026-10-02. Original ADR text was absent. Decisions below distinguish adopted
implementation choices from unresolved account, commercial, and legal decisions.

| ID | Status | Decision and rationale |
|---|---|---|
| ADR-001 | Adopted | Native SwiftUI/AppKit, minimum macOS 14, Swift 6 strict concurrency; no web wrapper |
| ADR-002 | Adopted | SwiftPM and command-line workflow; Xcode only when required for Apple tooling |
| ADR-003 | Adopted | Shared service protocols; DesignSystem is the only additional feature UI dependency |
| ADR-004 | Adopted | AVAudioEngine mic plus ScreenCaptureKit system audio; Core Audio taps remain a macOS 14.2+ gated experiment |
| ADR-005 | Adopted | Backend authorizes direct STT with temporary tokens; all LLM calls remain server-side |
| ADR-006 | Adopted | Fastify/TypeScript/pnpm; public health, asymmetric JWT verification, fail-closed auth |
| ADR-007 | Adopted | English first-run default, Turkish catalog translations, deterministic SwiftPM localization generation |
| ADR-008 | Adopted | Root design.md is visual reference only; docs/Design.md holds native visual adaptation; no website/product behavior imported |
| ADR-009 | Adopted | Cloud inference now; encrypted local cache later; synthetic sample workspace has no real capture or network effects |
| ADR-010 | Adopted | Begin with Shared, DesignSystem, MilyonusApp; add feature targets alongside real tested behavior |
| ADR-011 | Pending | Stable development signing identity and Apple team; ad hoc preview explicitly does not satisfy TCC persistence |
| ADR-012 | Pending | Hosting, region, and environments; prepare locally without provisioning paid resources |
| ADR-013 | Pending | Contracting entity, Apple/Stripe ownership, provider terms and retention commitments |
| ADR-014 | Adopted | Supabase access and refresh credentials may use Keychain; provider API secrets never enter client |
| ADR-015 | Adopted | Brand fonts are bundled only with redistribution licenses; system fonts are an explicit temporary fallback |
| ADR-016 | Deferred | Screen-share hiding is best effort, version-tested, never advertised as a privacy guarantee |

The owner authorized filling missing plans and continuing on 2026-10-02. Routine implementation
choices within these boundaries do not require repeated plan approvals. Installations, paid resources,
destructive operations, and legal/account decisions retain the applicable approval rules in AGENTS.md.
