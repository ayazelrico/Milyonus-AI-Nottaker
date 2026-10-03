# 01 - Product requirements

Reconstructed on 2026-10-02 from the supplied README, roadmap, owner instructions, and AGENTS.md.
This document does not claim to recover the missing original PRD. Task-level acceptance remains in
the roadmap and specs. The product is Milyonus Nottaker, not Milyonus AI Interviewer.

## Users and outcomes

Sales, consulting, and technical professionals need accurate meeting notes and timely help with
questions without losing focus. The first release is macOS-only with English first and Turkish second.
The UI is native SwiftUI/AppKit. No browser wrapper or website framework is used.

## Foundation requirements

| ID | Requirement | Acceptance |
|---|---|---|
| FR-01 | Native shell and menu bar access | Launch packaged app on macOS 14+; navigate workspace, meeting detail, knowledge base, settings |
| FR-02 | English default and Turkish localization | Every product string is localized; language selection persists; missing translations fall back to English |
| FR-03 | Authenticated backend boundary | Public health route; protected identity rejects invalid tokens; no provider secrets in app |
| FR-04 | Honest setup and sample state | Sample meeting is visibly labeled; unavailable recording/auth is not presented as working |
| NFR-01 | Isolated modules and concurrency | Swift 6 checking; external services behind Sendable Shared protocols |
| NFR-02 | Credential and content protection | No transcript/audio/token logging; keys stay on backend; user session uses Keychain |
| NFR-03 | Reproducible validation | Build, test, lint, catalog generation, and bundle checks are scripted |
| NFR-04 | Safe delivery | Focused commits; private repository; no secrets/build output in Git |
| NFR-05 | Stable application identity | App bundle and signing checked; persistent TCC tested separately from ad hoc preview |
| NFR-06 | Accessible native UI | Keyboard support, VoiceOver names, readable contrast, reduced-motion/transparency behavior |

## Subsequent phases

Live capture requires informed meeting consent before starting either audio channel. Capture both
mic and system audio, stream transcription, and present trigger-based assistance with citations when
KB grounding is available. P90 first-card latency <= 3 seconds is a measured target, not an initial
product promise. Manual ask is reserved as FR-13 for compatibility with the supplied roadmap.

Post-meeting output includes editable summary, decisions, action owners/dates, and an email draft.
Sending email is never automatic. KB upload, calendar integration, pre-call research, billing,
account deletion/export, and release distribution are separate phases with their own acceptance tests.

## Non-goals for Phase 0

Real capture, paid model calls, production authentication UI, provider provisioning, real meeting
storage, subscription charging, notarization, and public distribution. Sample content is synthetic,
contains no real participants, and must not trigger network requests.
