# 04 - Audio capture

Phase 1 specification, reconstructed on 2026-10-02. Microphone capture, system audio capture,
permissions, and the dual-channel synchronization mixer are implemented. Live consent, STT wiring,
replay, and real-device acceptance remain in their roadmap tasks.

Use AVAudioEngine for microphone capture and ScreenCaptureKit for system audio on macOS 14.
Put implementations behind Shared's audio source contract. Exclude this app from system audio.
Never use newer ScreenCaptureKit microphone APIs unconditionally. Core Audio taps are a separately
tested macOS 14.2+ experiment (ADR-004), not the baseline implementation.

Negotiate input formats, then emit 16 kHz mono PCM16 with channel identity and monotonic timestamps.
Preserve a common host clock, bound buffers, and account for dropped frames and discontinuities.
Audio callbacks do not allocate unbounded work, invoke cloud calls, log samples, or mutate UI.

Start only after meeting consent and OS authorization. Stop cancels both channels and downstream
streams. Device removal, default-device changes, sleep/wake, cancellation, and permission revocation
must produce explicit state and recoverable errors. Usage descriptions and entitlements do not grant
consent. Test resampling, channel identity, drift, hot-swap, and a 30-minute real/replay soak.
