# Integration plan

This is the owner-facing integration checklist for the first usable macOS build. It names the
providers to provision, the credentials to obtain, and the order in which they should be connected.
No secret belongs in this repository or in the macOS client.

## Recommended order

| Order | Integration | Decision | Owner action | Used by |
|---|---|---|---|---|
| 1 | Supabase Auth and Postgres | Primary identity and tenant data layer | Confirm Magic Link, then add Apple and Google provider credentials in the Supabase dashboard | Authentication, transcript sync |
| 2 | Deepgram | Primary live speech-to-text provider | Create a development API key with the minimum STT permissions and add it to `backend/.env.local` | Live English and Turkish transcription |
| 3 | AssemblyAI | Secondary STT provider for the P1-09 bake-off | Create a development key after Deepgram is working; do not enable it in production yet | Provider comparison only |
| 4 | Anthropic | Primary cloud inference provider | Create a server-only API key and verify organization data-use terms | Trigger classification, live cards, summaries |
| 5 | Sentry | Opt-in crash and performance diagnostics | Create a macOS project, configure scrubbing, and approve collection before adding the DSN | Release and beta diagnostics |
| 6 | Stripe | Billing and entitlements | Confirm the contracting entity, create test products and prices, then create restricted server credentials | Plans, checkout, portal, usage limits |
| 7 | Google Calendar | Calendar provider for pre-call workflows | Create a Google Cloud OAuth desktop/backend client, consent screen, and minimal calendar scopes | Phase 5 calendar integration |
| 8 | Voyage AI | Embeddings for the knowledge base | Verify English/Turkish quality and terms, then create a server-only key | Phase 4 retrieval |

## Credentials to prepare

Add values only to ignored local files or the CI secret store. Use the existing variable names where
present and keep all provider keys on the backend.

### `backend/.env.local`

```text
AUTH_ISSUER
AUTH_AUDIENCE
ANTHROPIC_API_KEY
DEEPGRAM_API_KEY
ASSEMBLYAI_API_KEY
VOYAGE_API_KEY
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY
STRIPE_SECRET_KEY
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_REDIRECT_URI
SENTRY_DSN
```

The client only receives `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and the optional
`BACKEND_BASE_URL`. Never put an Anthropic, STT, embedding, Stripe, Google client secret, or
Supabase service-role key in `app/.env.local`.

## Integration gates

- Supabase: complete one owner-controlled Magic Link sign-in and confirm `GET /v1/me`.
- Deepgram: run one consented English and one consented Turkish session, then inspect only IDs,
  durations, error codes, and segment counts in logs.
- AssemblyAI: collect the ten approved EN/TR recordings and record word error rate, endpointing,
  latency, language behavior, and terms in `docs/reports/stt-bakeoff.md`.
- Anthropic: wire model IDs through `backend/src/config/models.ts`; prompts remain versioned under
  `prompts/` and provider responses must not be logged.
- Sentry: verify transcript and audio fields are scrubbed before enabling collection.
- Stripe: use test mode until entity ownership, prices, webhook signing, and entitlements are
  approved.
- Google Calendar: request the smallest calendar scope and keep OAuth tokens server-side.
- Voyage: do not enable knowledge-base ingestion until retention, deletion, and injection tests are
  defined.

## Current status

- Supabase development project and migrations are ready.
- Native Supabase PKCE and Keychain flow is implemented; real account acceptance remains external.
- Deepgram token and WebSocket paths are implemented; provider account and live soak remain external.
- The remaining provider choices are intentionally unimplemented until the owner supplies account
  access and the relevant phase starts.
