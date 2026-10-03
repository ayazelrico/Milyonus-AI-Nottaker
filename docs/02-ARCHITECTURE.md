# 02 - Architecture

Reconstructed and adopted on 2026-10-02 under the owner's authorization. See docs/03 for decisions.

## Runtime

Native macOS SwiftUI/AppKit application -> authenticated TypeScript/Fastify backend -> AI services.
The backend issues short-lived STT access tokens after validating session, consent, and entitlement.
The app streams audio directly to STT using those tokens. Token TTL does not terminate an existing
stream; metering and session limits must be enforced separately before paid usage is enabled.

## Swift package

| Target | Dependencies | Ownership |
|---|---|---|
| Shared | Foundation only | Sendable domain types, external-service protocols, localization |
| DesignSystem | Shared, native UI frameworks | All visual tokens and reusable components |
| Authentication | Shared, pinned Supabase Auth SDK | PKCE sign-in, Keychain session, backend identity check |
| MilyonusApp | Shared, DesignSystem, Authentication | Composition root, windows, menu bar, sample workspace, settings |

Add AudioCapture, Transcription, InsightEngine, KnowledgeBase, PostMeeting, CalendarIntegration,
Persistence, and Billing targets when each receives tested behavior. Do not create
empty packages and tests merely to simulate implementation. Feature modules may depend on Shared
and DesignSystem; they cannot import each other. Only MilyonusApp wires implementations together.

External contracts cover audio source, STT stream, language generation, embeddings, meeting storage,
calendar, authentication, and entitlements. Provider SDK types never cross those interfaces. Use
actors for mutable stores and streaming state; UI state is MainActor-isolated. Audio callbacks must
hand off bounded data buffers rather than mutate UI or perform network work.

## Backend

Fastify owns route lifecycle. Configuration parsing is separate from process startup, so tests do
not need secrets or environment files. Production auth verifies asymmetric JWT signatures, issuer,
audience, expiry, subject, and authenticated role against configured JWKS. Auth is fail-closed when
unconfigured. Server keys never become app configuration. Health is public and does not expose
configuration, versions, credentials, or database details.

LLM IDs belong to backend/src/config/models.ts. Production prompts belong to prompts/ and require
evals before use. Initial foundation endpoints do not call STT, AI, billing, or databases.

## Resources and localization

English is the explicit first-run language, independent of the Mac's preferred language. Turkish can
be selected in settings. String Catalogs are source files. A deterministic build script emits
standard .lproj resources for plain SwiftPM, avoiding an Xcode requirement for basic localization.
Package resource bundles must be copied into the .app and verified outside the build directory.

## Storage and networking

Cloud inference does not prohibit local encrypted caches. The future authoritative account data
is in cloud Postgres with workspace isolation. Local transcript caches and rolling audio buffers
require explicit retention, encryption, and deletion tests before use. The Phase 0 sample lives
in memory only; only harmless preferences may use UserDefaults. Supabase access and refresh sessions
use an application-specific Keychain service. Public client configuration may be embedded in a local
generated bundle; provider and service-role secrets never enter the app.

## Distribution and observability

SwiftPM builds an executable; scripts package it into a native .app. Ad hoc signatures permit local
preview but do not satisfy stable privacy-permission or release acceptance. Developer ID,
notarization, DMG, and Sparkle arrive later. Operational logs contain event names, IDs, durations,
counts, and error codes only. Raw requests, tokens, transcripts, and audio are excluded.
