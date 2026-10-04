# P1-03 - System audio capture

Status: implementation in progress.

## Goal

Capture macOS system audio with ScreenCaptureKit on macOS 14, exclude the Milyonus process, normalize
audio to the shared 16 kHz mono PCM16 contract, and deliver it through a bounded `AudioSource` stream.

## Plan

1. Add a ScreenCaptureKit driver inside `AudioCapture` with no Apple framework types in `Shared`.
2. Select a display content filter, exclude this application by bundle identifier and PID, and add
   only an audio stream output.
3. Convert `CMSampleBuffer` audio through the existing persistent converter and preserve Core Media
   presentation timestamps in the shared monotonic nanosecond domain.
4. Surface permission, unavailable-content, format, start, and unexpected-stop errors explicitly.
5. Unit test actor state, bounded buffering, channel identity, and stop/failure behavior with fakes.

## Boundaries

- The source never requests screen-capture permission. P1-02 owns explicit permission UI.
- Starting capture remains a caller action after OS permission and per-meeting consent.
- No video output is registered, audio is not persisted, and samples are never logged.
- Per-app inclusion UI, mixing, and drift monitoring remain separate tasks.

## Acceptance

- The stream emits `.system` frames as mono signed PCM16 at 16 kHz.
- Milyonus audio is excluded in both the content filter and stream configuration.
- Buffers are bounded and dropped-frame metrics contain counts only.
- Cancellation and unexpected stream stops finish cleanly with deterministic tests.
- A signed packaged-app system-audio test is recorded before P1-03 is marked complete.
