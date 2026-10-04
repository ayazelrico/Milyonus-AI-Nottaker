# P1-01 - Microphone capture

Status: implementation in progress.

## Goal

Capture microphone audio through `AVAudioEngine`, normalize it to mono 16 kHz signed PCM16, attach
monotonic timestamps, and emit bounded frames through the `Shared.AudioSource` contract. Support the
system default input plus explicit device selection and recover from input-device configuration
changes without exposing AVFoundation or Core Audio types outside the feature module.

## Plan

1. Add an `AudioCapture` target depending only on `Shared` and Apple audio frameworks.
2. Add Sendable input-device values and a device-selection protocol to `Shared`.
3. Query microphone authorization without requesting it. P1-02 owns the explicit permission flow.
4. Wrap `AVAudioEngine` in a serialized driver. Install one bounded input tap, convert through a
   persistent `AVAudioConverter`, and emit only valid 16 kHz mono PCM16 frames.
5. Enumerate Core Audio input devices, identify the default device, and apply explicit selection to
   the engine input audio unit.
6. Observe engine configuration changes. Restart capture on a valid default/selected input and end
   the stream with a typed error when the selected device disappears or restart fails.
7. Unit test sample conversion, bounded stream behavior, state transitions, selection, and recovery
   with synthetic buffers and test drivers. Never require real microphone input in CI.

## Boundaries

- Launching the app does not request permission or start the engine.
- Audio callbacks do not touch UI, call the network, log sample data, or enqueue unbounded work.
- No audio bytes are persisted. Errors contain codes and device identifiers only, never samples.
- System audio, consent UI, permission UI, mixing, drift measurement, and STT transport remain in
  their roadmap tasks.

## Acceptance

- Swift 6 strict concurrency builds without warnings on macOS 14.
- Output is mono signed little-endian PCM16 at exactly 16 kHz with monotonic timestamps.
- The stream has a fixed buffering limit and reports dropped frames as metadata only.
- Default and explicit input-device selection are implemented behind `Shared` protocols.
- Configuration changes restart capture or fail explicitly, with deterministic tests.
- A signed packaged-app manual capture and hot-swap test is recorded before P1-01 is marked complete.
