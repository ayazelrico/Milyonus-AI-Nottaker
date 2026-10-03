# 09 - Post-meeting pipeline

Phase 3 specification, reconstructed on 2026-10-02. Foundation output is explicitly synthetic.

Ending a real meeting queues an idempotent summarization job. Use the configured Opus model and
versioned prompts to extract summary, decisions, action items, and follow-up email draft. Preserve
source segment references and distinguish unknown owners/dates from confirmed values. Chunk long
meetings with a measured map/reduce strategy and enforce cancellation/usage limits.

Users can edit, regenerate with a template, and export Markdown/PDF or copy text. Regeneration must
not silently overwrite edits. Email is a draft: the user explicitly opens mailto or copies content.
Never send an email as part of summarization. Retention and deletion must include jobs and caches.

Acceptance includes job retry/idempotency tests and summary/action precision/recall on the eval set.
The <= 60 second target for a 30-minute meeting is measured only after provider integration.
