# P1-08 - STT WebSocket client

Status: completed on 2026-10-05. Live meeting composition remains in P1-12 and P1-13. Provider
selection remains provisional until the P1-09 bake-off.

## Goal

Stream each 16 kHz mono PCM16 audio channel directly from the native app to Deepgram using the
short-lived backend credentials from P1-07. Produce bounded interim and final transcript events while
handling connection loss, cancellation, and credential refresh without exposing or logging content.

## Plan

1. Add a `Transcription` feature target that depends only on `Shared`.
2. Implement a backend token client with redacted credential values and typed status errors.
3. Wrap `URLSessionWebSocketTask` behind Sendable socket and factory contracts.
4. Configure Deepgram Nova-3 streaming for fixed English or Turkish and the existing PCM contract.
5. Map provider timing and revisions into stable `TranscriptSegment` identities.
6. Add keepalive, graceful close, bounded reconnect backoff, fresh tokens, and cancellation cleanup.
7. Verify all behavior with local fakes and no real provider calls.

## Connection contract

- One `transcribe` call accepts frames from exactly one audio channel.
- A second active session for the same channel is rejected. Microphone and system sessions may coexist.
- Each connection and reconnect calls `POST /v1/stt/token` through `STTTokenProvider`.
- The fixed provider endpoint is `wss://api.deepgram.com/v1/listen`; callers cannot override its host.
- Audio is binary signed PCM16 little-endian, mono, 16 kHz.
- Initial connect plus three reconnects are allowed. Backoff is 250, 500, then 1000 ms.
- Normal input completion sends `CloseStream` and waits up to two seconds for final events.
- A five-second `KeepAlive` prevents idle provider timeout.

## Event contract

Deepgram `Results` events become `TranscriptSegment` values. Empty transcripts and non-result metadata
are ignored. Missing fields, non-finite or negative timing, oversized messages, and malformed JSON fail
the connection. Interim and final revisions with the same start time share an ID. Exact duplicate events
are suppressed. Provider-relative timing receives a connection offset so reconnects remain on the shared
meeting timeline.

## Boundaries

- No provider call runs during tests and no credential, audio, or transcript is logged.
- The output buffer retains the newest 128 segments. Persistence and assembly belong to P1-10.
- The capture source remains responsible for its bounded frame buffer. P1-11 adds explicit rolling audio
  backfill and gap handling for longer outages.
- P1-09 decides the production provider after measured EN/TR quality and latency tests.
- P1-12 and P1-13 wire this service into live UI, capture, and consent state.

## Acceptance

- Strict Swift 6 concurrency build passes without warnings.
- Token responses and provider messages fail closed with typed, content-free errors.
- Request tests verify the fixed host, model, language, encoding, sample rate, and bearer header.
- Reconnect tests verify backoff and one fresh token per attempt.
- Result tests verify timing, channel identity, interim/final identity, and duplicate suppression.
- Cancellation and invalid channel changes close active work.
- Full repository build, tests, lint, formatting, hygiene, and CI pass.
