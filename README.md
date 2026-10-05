# Milyonus Nottaker

A native macOS AI notetaker and live meeting copilot, built with SwiftUI and a TypeScript backend.
This repository is the **Phase 0 foundation**. It is not a production recording application yet.

## Available now

- Native workspace, menu bar access, sample meeting library, summary/transcript detail, and copy.
- Explicit sample-data and disconnected-service states. No recording or upload on launch.
- English first-run default and Turkish UI, with persistent language selection.
- Shared service contracts, input validation, consent/readiness state transitions, and localization.
- Native DesignSystem with five base components and a debug-only component Gallery.
- Fastify backend with public health, fail-closed JWT-protected identity, and metadata-only logging.
- Authenticated STT token minting with explicit consent assertion, an entitlement boundary, and a
  server-only Deepgram adapter that returns 30-second access tokens.
- Native Supabase PKCE authentication foundation with Magic Link, Apple/Google entry points,
  Keychain-backed sessions, strict callback validation, and optional backend identity confirmation.
- Dedicated Supabase development schema with workspace RLS, transactional isolation tests, and
  generated backend types. It is not connected to the application yet.
- Native Deepgram streaming client with per-channel WebSockets, interim/final transcript events,
  keepalive, bounded reconnect backoff, cancellation, and fresh tokens on reconnect.
- Repository-local development tools, reproducible resources, signed local preview packaging, and CI.

Live meeting UI wiring, AI suggestions, cloud storage, calendar, and subscriptions are upcoming phases.
Authentication still needs one real acceptance sign-in. The sample summary is synthetic and is never
presented as generated output.

## Run the native preview

Requirements: macOS 14+, Swift 6 Command Line Tools or Xcode toolchain, and Python 3.9+.
No Xcode project or provider account is needed for the disconnected app preview.

```sh
python3 scripts/generate-localizations.py
swift build --package-path app
bash scripts/bundle-app.sh debug
open "build/Milyonus Nottaker.app"
```

The default bundle is ad hoc signed. This is suitable for local inspection; it is not notarized and
has not passed stable microphone/screen permission persistence testing. Use a configured signing
identity before recording permission acceptance. See [distribution](docs/18-RELEASE-DISTRIBUTION.md).
To test account sign-in, configure the ignored `app/.env.local` from `app/.env.example`, rebuild the
bundle, and allowlist `milyonus-nottaker://auth/callback` in the development Supabase project.

## Run the backend

Use the Node version in `.node-version` and pnpm version in `backend/package.json`.

```sh
pnpm --dir backend install --frozen-lockfile
pnpm --dir backend dev
```

`GET http://127.0.0.1:3000/health` returns `{"status":"ok"}`. `GET /v1/me` fails closed until Auth is
configured. See [backend API](docs/12-BACKEND-API.md) for configuration and route contracts. Configure
secrets privately in `backend/.env.local`; never paste or commit them. Do not use real meeting data
with this foundation.

## Verify

Install the pinned repository-local Swift tools with `bash scripts/install-swift-tools.sh` after
approving development dependencies. Then run `bash scripts/check.sh`. CI runs app/backend build,
tests, lint, localization checks, packaged resource smoke tests, and redacted secret scanning.
See [verification report](docs/reports/foundation-verification.md) for actual results and limitations.

## Architecture and planning

`app/` contains a SwiftPM package with Shared, DesignSystem, Authentication, AudioCapture,
Permissions, Transcription, and MilyonusApp. Feature
targets are added when they own tested behavior. `backend/` contains Fastify/TypeScript services. Provider credentials
stay on the backend; future direct STT streaming uses short-lived backend-issued tokens.

Read [AGENTS.md](AGENTS.md), then [Start Here](docs/00-START-HERE.md), [PRD](docs/01-PRD.md),
[architecture](docs/02-ARCHITECTURE.md), [decisions](docs/03-DECISIONS.md), and
[roadmap](docs/19-ROADMAP-TASKS.md). The missing planning set was explicitly reconstructed with the
owner's authorization. Remaining accounts and signing dependencies are tracked in
[open questions](docs/20-RISKS-OPEN-QUESTIONS.md).

The supplied root `design.md` is a visual reference only. [Native visual tokens](docs/Design.md)
and [UI behavior](docs/13-UI-UX-DESIGN-SYSTEM.md) separate brand styling from application requirements.
This product is distinct from Milyonus AI Interviewer and does not reuse its product claims or copy.
Bundled font licenses are documented in [third-party notices](THIRD_PARTY_NOTICES.md).

## Contributing

Follow [AGENTS.md](AGENTS.md), keep source/docs/commits in English, and use feature branches after
Phase 0. Never log transcript or audio content. Read [SECURITY.md](SECURITY.md) for private reporting.
