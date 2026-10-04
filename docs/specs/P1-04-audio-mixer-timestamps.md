# P1-04 - Audio mixer and timestamps

Status: completed on 2026-10-04. Real-device soak and the Phase 1 drift acceptance run remain P1-14.

## Goal

Coordinate microphone and system audio in one capture session while preserving their separate channel
identities for independent STT streams. Both sources use the shared monotonic host-clock nanosecond
domain. The mixer exposes one bounded frame stream and reports drift, timestamp discontinuities, and
output drops without inspecting, persisting, or logging audio samples.

## Plan

1. Extend the shared audio frame contract with exact duration and end-timestamp calculations.
2. Add Sendable synchronization metrics and an audio mixer service contract to `Shared`.
3. Implement an `AudioCapture` actor that starts both sources, merges their frames into a bounded
   output stream, preserves channel identity and timestamps, and stops both sources together.
4. Compare the latest frame-end timestamp for each channel. Track current and peak absolute drift,
   count samples above the 50 ms Phase 1 budget, and count per-channel timestamp regressions.
5. Fail the combined session explicitly if either source fails, ends unexpectedly, or emits the wrong
   channel. Clean up the first source if the second source cannot start.
6. Test lifecycle, drift, discontinuity, bounded output, startup cleanup, and failure propagation with
   deterministic synthetic sources. Real-device soak testing remains P1-14.

## Boundaries

- The mixer does not combine PCM samples or erase speaker-channel identity.
- It does not request permissions, create consent, connect to STT, persist audio, or log sample data.
- Source timestamps remain authoritative. The mixer observes and validates them rather than rewriting
  them from callback arrival time.
- A drift violation is an observation sample above 50 ms, not an automatic correction or invented gap.

## Acceptance

- Both sources start and stop as one session, including partial-start and downstream-cancellation paths.
- Output remains mono PCM16 at 16 kHz with original channel and monotonic host-clock timestamp values.
- The combined output buffer is fixed-size and reports dropped-frame counts.
- Current drift, peak drift, threshold violations, and timestamp discontinuities are deterministic.
- Swift 6 strict-concurrency build, tests, lint, package smoke tests, and CI pass.
