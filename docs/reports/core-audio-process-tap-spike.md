# Core Audio process tap spike

Date: 2026-10-04

Task: P1-05

Decision: Keep ScreenCaptureKit as the Phase 1 production baseline. Retain Core Audio process taps
as a measured, macOS 14.2+ experiment only.

## Evidence

Apple exposes `AudioHardwareCreateProcessTap` and `AudioHardwareDestroyProcessTap` on macOS 14.2
and later. A `CATapDescription` selects included or excluded Core Audio process object IDs, chooses
mono or stereo mixdown, controls whether the tap is private, and controls whether captured playback
remains audible. The tap becomes an input of a HAL aggregate device, which is then read through an
audio device I/O callback.

The installed SDK also exposes aggregate-device tap composition, private ephemeral aggregate
devices, tap auto-start, and drift compensation for aggregate sub-taps. Direct `bundleIDs` selection
and automatic process restoration are declared for macOS 26, so the app cannot rely on those
conveniences at its macOS 14 deployment target. A macOS 14.2 implementation must discover current
Core Audio processes, map the required process object IDs, and respond to process turnover itself.

Apple documents `NSAudioCaptureUsageDescription` and a system-audio recording permission prompt for
the tap flow. These OS permissions remain separate from Milyonus meeting consent.

Sources:

- [Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription)
- [AudioHardwareTap](https://developer.apple.com/documentation/coreaudio/audiohardwaretap)
- Installed macOS SDK headers: `CoreAudio/CATapDescription.h`,
  `CoreAudio/AudioHardwareTapping.h`, and `CoreAudio/AudioHardware.h`

## Comparison

| Area | ScreenCaptureKit baseline | Core Audio process tap |
|---|---|---|
| Minimum OS | Works with the project's macOS 14 target | Tap creation requires macOS 14.2 |
| Current implementation | Implemented behind `AudioSource`, audio-only, bounded, normalized, and tested | No repository implementation |
| Process filtering | `SCContentFilter` excludes selected running applications; the stream also sets `excludesCurrentProcessAudio` | Includes or excludes Core Audio process object IDs; direct bundle-ID configuration requires macOS 26 |
| Data path | `SCStream` emits audio sample buffers | Tap plus private aggregate device plus audio device I/O callback |
| Format work | Existing converter produces 16 kHz mono PCM16 | Tap/device format discovery and conversion are still required |
| Clocking | Core Media timestamps enter the shared host-clock contract; P1-04 measures cross-channel drift | HAL aggregate devices expose clock and sub-tap drift controls, but end-to-end drift still requires measurement |
| Lifecycle | Content discovery, stream start/stop, and output callbacks | Process discovery, tap create/destroy, aggregate create/destroy, I/O callback registration, device changes, and cleanup |
| Permissions | Screen/system-audio capture permission managed by the existing permission flow | System-audio capture usage description and permission flow must be verified in the signed app |
| Main opportunity | Lowest delivery risk for the current target and architecture | More direct HAL integration and process-oriented selection on supported systems |
| Main risk | Per-app identity and capture behavior can change when applications restart | Larger failure and cleanup surface, 14.2 availability split, and process-ID churn on the supported baseline |

## Engineering assessment

The Core Audio tap path is technically viable and does not require a custom virtual audio driver.
It is not a drop-in replacement for `SCStream`. It adds an aggregate audio device and process-object
lifecycle that the app would own. The current product does not have measured SCK latency, drift,
filtering, or reliability failures that justify carrying two production capture stacks.

Core Audio's aggregate clock and drift controls may improve behavior, but the API surface alone does
not prove lower latency or lower microphone-to-system drift. P1-04 already records drift at the shared
frame boundary, and P1-14 will provide the first production-relevant measurement. That evidence must
drive any change.

## Decision and experiment gate

ScreenCaptureKit remains the only production system-audio source for Phase 1 and supports the full
macOS 14 deployment target. A Core Audio process tap prototype may begin only if P1-14 or later field
telemetry shows one of these repeatable failures:

- cross-channel drift exceeds 50 ms after timestamp and converter defects are excluded;
- required application audio cannot be selected or excluded reliably with ScreenCaptureKit;
- measured capture latency prevents the live insight latency target;
- signed-app capture stability fails the 30-minute soak target on supported hardware.

Any prototype must:

1. Be isolated behind the existing `AudioSource` protocol and guarded with macOS 14.2 availability.
2. Use a private, non-muting tap and a private ephemeral aggregate device.
3. Exclude Milyonus audio and handle process launch, exit, default-device changes, sleep, and wake.
4. Destroy the I/O procedure, aggregate device, and process tap on every stop and failure path.
5. Emit the existing 16 kHz mono PCM16 frames without logging or persisting sample content.
6. Run against the same EN/TR fixtures and signed-device soak matrix as ScreenCaptureKit.
7. Compare CPU, memory, first-frame latency, discontinuities, dropped frames, drift, and recovery.

Adopt the tap path only if it produces a material, repeatable improvement and the macOS 14.0 to 14.1
fallback remains tested. Otherwise remove the prototype after the report.
