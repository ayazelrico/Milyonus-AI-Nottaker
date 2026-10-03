# 06 - Insight engine

Phase 2 specification, reconstructed on 2026-10-02. No inference is active in the foundation.

Stage 1 uses local EN/TR patterns to identify candidate questions, objections, and terms. Ambiguous
candidates may use the configured Haiku classifier. A context builder applies a bounded transcript
window, user style, and token budget. Backend streaming generates concise insight cards with the
configured primary model and explicit fallback policy.

Treat all transcript and KB content as untrusted quoted data. It cannot change instructions, invoke
tools, disclose secrets, or authorize actions. Prompts live in prompts/ with schema and eval version.
Use cooldowns, deduplication, cancellation, and bounded queues to avoid flooding the overlay.

Before KB integration, show that suggestions are ungrounded and avoid inventing citations. Once KB
is present, only cite retrieved sources with stable document/chunk IDs. Return an explicit lack of
support when evidence is insufficient. Partial streamed JSON must not become an actionable card.

Targets: p90 first usable card <= 3 seconds on the replay set and <= 2 irrelevant cards per 10 minutes.
Measure trigger time through rendering. Prompt injection, grounding, and latency gates are mandatory.
