# 05 - Transcription

Phase 1 specification, reconstructed on 2026-10-02. The provider client is implemented but not yet
wired to live capture or a transcript window.

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

P1-08 adds the native `Transcription` module. `BackendSTTTokenClient` requests a credential immediately
before each initial connection or reconnect. `DeepgramTranscriptionService` opens one `/v1/listen`
WebSocket per audio-channel stream with Nova-3, fixed EN or TR, linear16 mono at 16 kHz, interim
results, punctuation, smart formatting, and 300 ms endpointing. It sends binary PCM frames, a
five-second keepalive while idle, and `CloseStream` at normal input completion.

The client maps provider result timing onto the shared meeting timeline, preserves one segment ID as
an interim result becomes final, suppresses exact duplicate events, and accepts reordered timestamps.
A closed or failed connection triggers at most three reconnects with 250, 500, and 1000 ms delays.
Every attempt obtains a new backend token. Cancellation closes the socket and stops both receiver and
keepalive work. The output stream is bounded to its newest 128 segments. P1-10 owns durable assembly
and storage; P1-11 owns rolling audio backfill when frames are lost during a longer network outage.

Deepgram is provisional until an EN/TR bake-off against an alternative. Verify language/model,
streaming, punctuation, diarization, endpointing, token, and data-use behavior at implementation time.
Fixed-language Turkish support is not proof of EN/TR code-switching quality. Temporary-token expiry
is checked at connection creation and does not itself terminate an active WebSocket.

Handle interim replacement, final segment identity, duplicate/reordered events, reconnect/backoff,
token renewal on reconnect, cancellation, bounded offline buffers, and explicit gaps. Never silently
invent missing transcript text. Measure word error rate, endpoint latency, and speaker attribution
with synthetic/licensed EN/TR fixtures. Never log text or audio.

Provider behavior was verified on 2026-10-05 from Deepgram's official
[live audio reference](https://developers.deepgram.com/reference/speech-to-text/listen-streaming),
[endpointing guide](https://developers.deepgram.com/docs/understand-endpointing-interim-results/), and
[model/language matrix](https://developers.deepgram.com/docs/models-languages-overview/). Nova-3 lists
both English and Turkish streaming support. P1-09 still owns measured provider selection.
