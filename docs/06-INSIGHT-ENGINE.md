# 06 - Insight engine

Phase 2 specification, reconstructed on 2026-10-02. Inference is disabled by default; the development
backend path described below requires an explicit runtime switch.

Stage 1 uses local EN/TR patterns to identify candidate questions, objections, and terms. Ambiguous
candidates may use the configured Haiku classifier. A context builder applies a bounded transcript
window, user style, and token budget. Backend streaming generates concise insight cards with the
configured primary model and explicit fallback policy.

The first prompt contracts are versioned in `prompts/trigger-classifier.v1.md` and
`prompts/live-insight.v1.md`, with JSON Schemas beside them. They remain drafts until the labeled eval
set and provider acceptance are complete. The backend now loads these contracts and validates their
output. No prompt may be promoted to production without the corresponding eval run.

## Development backend implementation

`POST /v1/insights/stream` accepts an authenticated caller's bounded EN/TR transcript window and
trigger, with `consentConfirmed: true`. The route checks the existing entitlement boundary, limits
concurrent work, and sends count-only progress before a complete validated card. Before retrieval,
cards always have `grounding: "transcript_only"` and an empty citation array. Classifier evidence must
appear literally in its input. Both validators reject extra fields and invalid confidence/lengths.

The Anthropic adapter uses server-only credentials, a ten-second total deadline, one transient retry,
and the configured Haiku fallback for live insight before any text has arrived. Partial output,
refusals, truncation, and invalid JSON are never retried or promoted to cards. Sonnet's request
options are centralized alongside the model identifiers. Only the static system prefix is marked for
provider caching. Short prompts may not meet the provider's cache threshold; cache savings are not
assumed. No backend transcript or response cache exists.

The SSE response lifetime is capped at twelve seconds, including slow readers. A disconnect cancels
generation. Completed provider token counts, cache counts, attempts, and duration are logged as
allowlisted metadata, including completed output rejected by validation. Counts from failed streams
can be incomplete and are not billing-grade metering. There is no prompt/output logging.

`INSIGHTS_DEVELOPMENT_ENABLED=true` and `ANTHROPIC_API_KEY` are both required. Production rejects the
development switch. Tests/evals are deferred at the owner's request, so P2-01 to P2-03 remain open.
The native client, local trigger detector, and floating overlay have not been connected to this route.
See `specs/P2-02-insight-backend.md` for the deferred acceptance matrix.

## Provider contract review (2026-10-09)

The adapter follows the official [Messages API](https://platform.claude.com/docs/en/api/messages/create),
[streaming contract](https://platform.claude.com/docs/en/build-with-claude/streaming), and
[prompt caching guide](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).
Sonnet 5.5 text-only calls use `thinking.type: "between_tools"` and low effort, as specified in the
[Sonnet migration notes](https://platform.claude.com/docs/en/models/sonnet-5-5/whats-new-sonnet-5-5).
The approved pinned [Haiku 4.5 model](https://platform.claude.com/docs/en/models/haiku-4-5/overview)
remains in configuration; account access and lifecycle must be rechecked before provider acceptance.

Treat all transcript and KB content as untrusted quoted data. It cannot change instructions, invoke
tools, disclose secrets, or authorize actions. Prompts live in prompts/ with schema and eval version.
Use cooldowns, deduplication, cancellation, and bounded queues to avoid flooding the overlay.

Before KB integration, show that suggestions are ungrounded and avoid inventing citations. Once KB
is present, only cite retrieved sources with stable document/chunk IDs. Return an explicit lack of
support when evidence is insufficient. Partial streamed JSON must not become an actionable card.

Targets: p90 first usable card <= 3 seconds on the replay set and <= 2 irrelevant cards per 10 minutes.
Measure trigger time through rendering. Prompt injection, grounding, and latency gates are mandatory.
