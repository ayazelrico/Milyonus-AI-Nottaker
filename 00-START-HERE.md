# Supplied planning reference

This file preserves the original supplied plan. The maintained version is [docs/00-START-HERE.md](docs/00-START-HERE.md).
Original estimates and account/environment assumptions below are historical reference only.

# 00 - Start Here

How to go from these documents to a running project. Follow in order.

## 1. Machine prerequisites (Day 1)

- A Mac on macOS 15 or newer is recommended for development (target minimum for users: macOS 14).
- Install Xcode from the App Store (needed for signing, notarization tools and SDKs even though you code in VS Code),
  then `xcode-select --install` and open Xcode once to accept the license.
- Full list and VS Code configuration: `docs/17-DEV-SETUP-VSCODE.md`.

## 2. Accounts to open (Phase 0, week 1)

| Service | Why | Notes |
|---|---|---|
| Apple Developer Program | Developer ID signing, notarization | Needs a paid membership. Decide whether it is enrolled under the Turkish or the US entity (see `docs/20`) |
| Anthropic API (org account) | Insights, summaries, briefs | Ask about Zero Data Retention eligibility |
| Deepgram | Primary streaming STT | Run the EN/TR bake-off in Phase 1 |
| AssemblyAI | Alternative STT for bake-off | Same |
| Voyage AI (or chosen embedding provider) | KB embeddings | Verify multilingual EN/TR quality |
| Supabase | Auth, Postgres + pgvector, Storage | One project for dev, one for prod |
| Fly.io (or Railway/Render) | Backend hosting with long-lived connections | Pick one, record in ADR |
| Stripe | Subscriptions | Which entity owns the account: see `docs/20` |
| Sentry | Crash and error reports | Scrub PII |
| GitHub | Repo, CI (macOS runners) | Private repo |
| Domain + DNS | Landing page, appcast, auth redirects | Under the Milyonus brand |
| Google Cloud project | Google Calendar OAuth (v1) | OAuth consent screen verification takes time: start early |

Store all keys in `backend/.env.local` (never committed). Only `.env.example` is committed.

## 3. Create the repo

1. Create a private GitHub repo named `Milyonus-AI-Nottaker`.
2. Copy this documentation folder into it as the initial commit.
3. Open the folder in VS Code. Install the recommended extensions (`docs/17`).
4. Open Claude Code in the repo root.

## 4. Build order (high level)

`Phase 0` repo + accounts + skeletons -> `Phase 1` audio + transcript -> `Phase 2` live insights ->
`Phase 3` summaries -> `Phase 4` knowledge base -> `Phase 5` calendar + briefs -> `Phase 6` polish + billing +
security -> `Phase 7` beta + distribution. Details and task IDs: `docs/19-ROADMAP-TASKS.md`.

Billing and auth are pulled earlier than in a typical plan because "fully cloud" means every AI call goes
through the authenticated backend from Phase 1 onward. Minimal auth lands in Phase 0/1; full Stripe in Phase 6.

## 5. First Claude Code session prompts

Paste these one at a time. Always approve the plan before the code.

**Prompt 1 - orient**
> Read AGENTS.md, README.md, docs/01-PRD.md, docs/02-ARCHITECTURE.md and docs/19-ROADMAP-TASKS.md.
> Summarize the project in 10 lines in Turkish, list the Phase 0 tasks, and tell me anything in the docs
> that looks inconsistent or missing. Do not write code yet.

**Prompt 2 - scaffold the Swift package (plan mode)**
> Run /plan-feature for task P0-03: create the Swift package skeleton in app/ exactly as in
> docs/02-ARCHITECTURE.md (targets, dependency rules, empty protocols in Shared, one passing test per module,
> SwiftLint and SwiftFormat configs). Show the plan first.

**Prompt 3 - scaffold the backend (plan mode)**
> Run /plan-feature for task P0-04: backend skeleton (Fastify + TypeScript + pnpm, health route,
> Supabase JWT auth middleware stub, config loader that reads env, models config, Vitest, ESLint, .env.example).

**Prompt 4 - the dev app bundle (critical for audio permissions)**
> Run /plan-feature for task P0-05: scripts/bundle-app.sh that builds the SwiftPM executable into a signed
> .app bundle with Info.plist, entitlements and a stable bundle id, so macOS permissions persist between runs.
> Follow docs/17-DEV-SETUP-VSCODE.md and docs/18-RELEASE-DISTRIBUTION.md.

**Prompt 5 - first real feature**
> Run /plan-feature for task P1-01: microphone capture with AVAudioEngine behind the AudioSource protocol,
> 16 kHz mono PCM16 output, device selection and hot-swap, plus unit tests with a fake source.

## 6. Working rhythm

- One task ID per session. Spec -> plan -> implement -> `/finish-task`.
- Tick the checkbox in `docs/19-ROADMAP-TASKS.md` when a task is done.
- Every Friday: run `/phase-check` for the current phase and update `docs/20-RISKS-OPEN-QUESTIONS.md`.
