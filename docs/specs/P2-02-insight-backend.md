# P2-01 to P2-03 - Development insight backend

## Scope

Implement the backend pieces that do not require provider credentials: strict output validators,
repository prompt loading, an Anthropic Messages stream adapter, and the first insight SSE route.
The owner's 2026-10-06 instruction defers test runs and provider evaluations. These tasks remain
open until their contract tests, prompt evaluations, and runtime acceptance are complete.

## Behavior

1. `ANTHROPIC_API_KEY` alone never enables model calls. Explicit
   `INSIGHTS_DEVELOPMENT_ENABLED=true` enables this path only outside production.
2. Authenticate and check consent and the existing entitlement boundary before generating anything.
3. Read allowlisted prompt filenames relative to the repository, independent of the working
   directory. Do not place prompts in source code or allow the client to select files or models.
4. Bound input, output, stream events, concurrency, and total request duration. Cancel on disconnect.
5. Stream character-count progress, then one validated card and a completion event. Never forward
   partial JSON, provider errors, thinking, or tools to the app.
6. Retry transient failures once before any output; use the configured live fallback on another
   transient failure. All attempts share one deadline. Never retry invalid output or partial streams.
7. Cache only the static provider system prefix. Do not cache user content or completed responses
   in this backend. Record usage counts with metadata-only operational events.
8. Reject extra output properties, bad confidence, excessive lengths, citations before retrieval,
   and classifier evidence absent from its input.

## Deferred acceptance

- Contract cases: invalid/extra fields, empty text, invented evidence/citations, partial/truncated JSON.
- Stream cases: split UTF-8, LF/CRLF/CR framing, pings, unknown events, overload, truncated stream,
  stop reason, token usage, retry/fallback, timeout, cancellation, and backpressure.
- Route cases: missing/invalid auth, consent, denied entitlement, disabled provider, invalid input,
  concurrency/cooldown, client disconnect, safe logging, and a validated final card.
- EN/TR labeled classification and insight evaluations with a holdout set. Safety cases must all pass;
  measure relevance and first-card latency against Phase 2 acceptance before production promotion.
- Real provider availability, organization terms, and account model access.

## Constraints

No installations, cloud provisioning, live provider calls, Swift changes, or production enablement.
The existing allow-all entitlement stub cannot authorize paid public rollout. This endpoint accepts
caller-supplied transcript data and does not fetch or persist workspace data.
