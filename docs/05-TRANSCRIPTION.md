# 05 - Transcription

Phase 1 specification, reconstructed on 2026-10-02. No STT client is active in the foundation.

The authenticated backend mints a short-lived provider token only after consent and entitlement
checks. The client establishes one stream per audio channel. Provider adapters implement Shared
contracts without exposing SDK types. Permanent keys never enter the app.

Deepgram is provisional until an EN/TR bake-off against an alternative. Verify language/model,
streaming, punctuation, diarization, endpointing, token, and data-use behavior at implementation time.
Fixed-language Turkish support is not proof of EN/TR code-switching quality. Temporary-token expiry
is checked at connection creation and does not itself terminate an active WebSocket.

Handle interim replacement, final segment identity, duplicate/reordered events, reconnect/backoff,
token renewal on reconnect, cancellation, bounded offline buffers, and explicit gaps. Never silently
invent missing transcript text. Measure word error rate, endpoint latency, and speaker attribution
with synthetic/licensed EN/TR fixtures. Never log text or audio.
