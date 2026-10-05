# 19 - Roadmap and Task List

Task IDs: `P<phase>-<nn>`. Tick `[x]` when done. Work from a task spec, implement in verified increments, and record actual completion.
Durations are estimates, not delivery guarantees. External account/signing dependencies are tracked separately.


## Foundation status (2026-10-04)

The missing planning set has been reconstructed under the owner's authorization. Local implementation
is being verified. A runnable local preview does not satisfy cloud deployment, stable TCC signing,
provider accounts, or legal acceptance. See `docs/reports/foundation-verification.md` for the final
command results and `docs/accounts-checklist.md` for external dependencies.

## Phase 0 - Foundations (1 week)

Goal: repo, accounts, skeletons, bundling, CI. Acceptance: empty app launches as a signed dev bundle; backend health route deployed to dev; CI green.

- [ ] P0-01 Repo hygiene: `.gitignore`, `.editorconfig`, lint configs, PR template, Dependabot, `SECURITY.md`, branch protection
- [ ] P0-02 Accounts and keys opened (list in `00-START-HERE.md`); keys stored in `.env.local` / secret stores; record in a private checklist (no keys in repo)
- [x] P0-03 Swift package per `02-ARCHITECTURE.md`; protocols in `Shared`; meaningful tests for implemented modules
- [x] P0-04 Backend skeleton: Fastify, config, health route, JWT middleware, Vitest, ESLint, `.env.example`
- [ ] P0-05 `scripts/bundle-app.sh` + entitlements + Info.plist + stable dev signing; app launches with menu bar icon
- [x] P0-06 Supabase environments (region and dev/staging/prod split approved before provisioning), migrations folder, initial schema (`users`, `workspaces`, `profiles`, `meetings`, `transcript_segments`), RLS tests
- [ ] P0-07 Auth: implementation complete for Magic Link, Apple/Google entry points, PKCE, Keychain,
  callback handling, and `GET /v1/me`; dashboard redirect is configured and real Magic Link acceptance remains
- [ ] P0-08 CI: app build/test/lint on macOS runner; backend build/lint/test; secret scanning; approved dev health deployment
- [x] P0-09 DesignSystem v0: tokens, fonts registered, Gallery window with 5 base components
- [ ] P0-10 Legal groundwork: data map draft, provider terms checklist (ZDR, training), decide contracting entity (see `20`)

## Phase 1 - Audio and Transcript (2 weeks)

Acceptance: 30-minute meeting captured on both channels, live EN/TR transcript, no crash, drift < 50 ms, permission flow clear.

- [ ] P1-01 Mic capture (AVAudioEngine) behind `AudioSource`, 16 kHz mono PCM16, device selection + hot-swap
- [ ] P1-02 Permissions manager (mic, screen/system audio, notifications) with deep links and restart-required handling
- [ ] P1-03 System audio via ScreenCaptureKit (all apps except self), downmix/resample, per-app filter
- [x] P1-04 Mixer/timestamps: shared host clock, frame contract, drift monitor, bounded buffers
- [x] P1-05 Spike: Core Audio process tap vs SCK; write findings in ADR-004 update
- [x] P1-06 `ReplaySource` + fixtures (EN, TR) + Debug "Run replay" menu
- [x] P1-07 Backend `POST /v1/stt/token` with Deepgram adapter (short-lived tokens), entitlement stub
- [x] P1-08 STT client: WebSocket session per channel, events, reconnect/backoff, token refresh
- [ ] P1-09 Bake-off: Deepgram vs AssemblyAI on 10 recordings (EN/TR); report in `docs/reports/stt-bakeoff.md`; pick primary; implement secondary adapter
- [x] P1-10 `SegmentAssembler`, `TranscriptStore` actor, local persistence (GRDB, encrypted text), outbox + `PUT segments:batch`
- [x] P1-11 Local rolling audio buffer + backfill after network drop
- [ ] P1-12 Minimal live transcript window + menu bar start/stop + listening indicator
- [ ] P1-13 Consent sheet v0 and `consent_confirmed` plumbing (required by `stt/token`)
- [ ] P1-14 30-minute soak test (live and replay), performance snapshot

## Phase 2 - Live Insights (2 weeks)

Acceptance: p90 first card <= 3 s on replay set; <= 2 irrelevant cards / 10 min; eval gates in `07` pass for EN.

- [ ] P2-01 Prompt files v1: trigger classifier + live insight (`prompts/`), schema + validator
- [ ] P2-02 Backend LLM wrapper (streaming, caching, retries, timeouts, usage), models config
- [ ] P2-03 `POST /v1/insights/stream` SSE (no KB yet) + contract tests
- [ ] P2-04 TriggerDetector stage 1 (EN lexicons, TR lexicons), unit tests with labeled set
- [ ] P2-05 Stage 2 Haiku classifier route + fallback behavior
- [ ] P2-06 ContextBuilder (window, profile, style) + token budgeting
- [ ] P2-07 InsightClient (SSE) + progressive card model + rate limiter/cooldowns/dedupe
- [ ] P2-08 Overlay NSPanel (floating, non-activating, full-screen aux, drag/resize, opacity, click-through)
- [ ] P2-09 Card UI per spec, shortcuts, copy/dismiss/pin, feedback buttons
- [ ] P2-10 Manual ask (FR-13)
- [ ] P2-11 Eval harness + datasets v1 (EN) + nightly run; TR set started
- [ ] P2-12 Latency instrumentation + dashboards; tune endpointing and prompts to hit budget
- [ ] P2-13 Screen-share hiding setting (best effort) tested on supported macOS versions (ADR-016)

## Phase 3 - Post-Meeting Pipeline (1-2 weeks)

Acceptance: summary + actions in <= 60 s for 30 min meeting; recall/precision >= 0.85; editable and persisted.

- [ ] P3-01 Prompts: summary v1, email-draft v1; JSON schemas; templates seed (General, Sales, Interview, Consulting)
- [ ] P3-02 Job queue (pg-boss) + `summarize_meeting` worker (Opus 5.5), map/reduce for long meetings
- [ ] P3-03 Summary/action-item tables, endpoints, sync to app
- [ ] P3-04 Meeting list + detail UI (Summary, Transcript, Actions, Email tabs), editing, regenerate with template
- [ ] P3-05 Email draft flow (`mailto:` + copy), tones
- [ ] P3-06 Export (Markdown, PDF, clipboard)
- [ ] P3-07 Transcript search decision + implementation (record ADR on local vs cloud search)
- [ ] P3-08 Summary evals (EN) and TR dataset
- [ ] P3-09 Retention settings + delete meeting end-to-end

## Phase 4 - Knowledge Base (2 weeks)

Acceptance: 50-page PDF searchable <= 60 s; top-4 recall >= 90% EN / 80% TR; cited insights within latency budget.

- [ ] P4-01 Schema: collections, documents, chunks, glossary, indexes (HNSW, GIN), RLS
- [ ] P4-02 Upload flow (signed URLs) + status updates
- [ ] P4-03 Ingestion worker: PDF, DOCX, TXT, MD, URL (with SSRF protections)
- [ ] P4-04 Chunker (structure-aware) + embeddings (Voyage) + glossary extraction
- [ ] P4-05 Hybrid search + RRF (+ optional rerank) + `kb/search` route
- [ ] P4-06 Wire retrieval into `insights/stream`; citations in cards; "not in KB" behavior
- [ ] P4-07 KB UI: collections, drag-drop upload, document viewer, test-question box, glossary editor
- [ ] P4-08 STT keyterms from glossary
- [ ] P4-09 Grounding and injection eval suites; fix failures
- [ ] P4-10 KB limits per plan

## Phase 5 - Calendar and Pre-Call Briefs (1-2 weeks)

Acceptance: calendar flows work; detection prompt within 10 s of call start (90%); brief < 90 s with sources.

- [ ] P5-01 EventKit integration + permission step
- [ ] P5-02 Google OAuth (backend code flow) + events endpoint
- [ ] P5-03 Meeting detector (calendar + running apps + audio activity) + notification actions
- [ ] P5-04 Link meetings to calendar events (attendees, title, template suggestion)
- [ ] P5-05 Brief prompt + worker with web search; sources required; privacy filters
- [ ] P5-06 Brief UI + 15-minute notification + on-demand brief
- [ ] P5-07 Settings: briefs on/off, lead time, domain exclusions

## Phase 6 - Polish, Billing, Security (2 weeks)

Acceptance: onboarding < 5 min on a clean Mac; Stripe test flow green; security checklist complete; legal docs live.

- [ ] P6-01 Onboarding flow (all steps in `13`), restart-required handling, test audio screen
- [ ] P6-02 Settings: languages, devices, shortcuts, models/style, privacy, data export/delete
- [ ] P6-03 Turkish localization pass (String Catalogs), layout checks
- [ ] P6-04 Plans config, Stripe checkout/portal/webhooks, entitlements enforcement everywhere
- [ ] P6-05 Usage metering + usage UI + warnings; abuse limits
- [ ] P6-06 Account deletion + full export
- [ ] P6-07 Security review per `14` (checklists, dependency audit, log scan, RLS audit)
- [ ] P6-08 Privacy policy, ToS, DPA, KVKK notice, subprocessor list (lawyer review)
- [ ] P6-09 Accessibility pass
- [ ] P6-10 Performance pass (CPU/memory/latency) and soak tests
- [ ] P6-11 Runbooks (`docs/runbooks/`) and QA checklists (`docs/qa/`)

## Phase 7 - Beta and Distribution (2 weeks)

Acceptance: notarized DMG, Sparkle updates verified, 10-20 beta users, crash-free > 99%.

- [ ] P7-01 Release scripts (sign, notarize, DMG, appcast) and CI release workflow
- [ ] P7-02 Sparkle integration + beta channel + forced-upgrade handling
- [ ] P7-03 Landing page + download + docs (separate from AI Interviewer pages)
- [ ] P7-04 Beta invites, feedback widget, diagnostics export
- [ ] P7-05 Sentry + analytics (opt-in) dashboards
- [ ] P7-06 Beta bug-bash cycles; fix S1/S2
- [ ] P7-07 Stripe live-mode dry run
- [ ] P7-08 Public launch checklist (`18`)

## After v1 (v2 backlog)

Workspaces/teams and shared KBs, CRM integrations (HubSpot/Salesforce), Microsoft 365 calendar, more languages,
hybrid-local mode (`22`), analytics dashboards, coaching metrics, mobile companion, Mac App Store evaluation.
