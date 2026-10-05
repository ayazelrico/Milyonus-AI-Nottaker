# 05 - Transcription

Phase 1 specification, reconstructed on 2026-10-02. No STT client is active in the foundation.

The authenticated backend mints a short-lived provider token only after consent and entitlement
checks. The client establishes one stream per audio channel. Provider adapters implement Shared
contracts without exposing SDK types. Permanent keys never enter the app.

P1-07 implements `POST /v1/stt/token` with Deepgram's token-based authentication endpoint. It asks
Deepgram for a 30-second bearer token, validates the provider response, and returns only the temporary
credential and expiry duration. The permanent key remains in backend configuration. The route requires
an authenticated non-anonymous user, the exact body `{"consentConfirmed":true}`, and a positive
entitlement check before contacting Deepgram. The Phase 1 entitlement checker is an explicit allow-all
stub for authenticated users. P1-13 will connect the assertion to the native consent flow, and P6-04
will replace the entitlement stub with billing-backed authorization. This route must not be treated as
production-ready until those tasks and abuse controls are complete.

Deepgram is provisional until an EN/TR bake-off against an alternative. Verify language/model,
streaming, punctuation, diarization, endpointing, token, and data-use behavior at implementation time.
Fixed-language Turkish support is not proof of EN/TR code-switching quality. Temporary-token expiry
is checked at connection creation and does not itself terminate an active WebSocket.

Handle interim replacement, final segment identity, duplicate/reordered events, reconnect/backoff,
token renewal on reconnect, cancellation, bounded offline buffers, and explicit gaps. Never silently
invent missing transcript text. Measure word error rate, endpoint latency, and speaker attribution
with synthetic/licensed EN/TR fixtures. Never log text or audio.
