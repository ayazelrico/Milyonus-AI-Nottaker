# 04 - Audio capture

Phase 1 specification, reconstructed on 2026-10-02. Microphone capture, system audio capture,
permissions, the dual-channel synchronization mixer, and synthetic EN/TR replay sources are
implemented. Live consent, STT wiring, and real-device acceptance remain in their roadmap tasks.

Use AVAudioEngine for microphone capture and ScreenCaptureKit for system audio on macOS 14.
Put implementations behind Shared's audio source contract. Exclude this app from system audio.
Never use newer ScreenCaptureKit microphone APIs unconditionally. The P1-05 spike keeps Core Audio
process taps as a measurement-triggered macOS 14.2+ experiment (ADR-004), not the baseline
implementation. P1-14 drift, latency, filtering, or stability evidence must justify starting it.

Negotiate input formats, then emit 16 kHz mono PCM16 with channel identity and monotonic timestamps.
Preserve a common host clock, bound buffers, and account for dropped frames and discontinuities.
Audio callbacks do not allocate unbounded work, invoke cloud calls, log samples, or mutate UI.

Start only after meeting consent and OS authorization. Stop cancels both channels and downstream
streams. Device removal, default-device changes, sleep/wake, cancellation, and permission revocation
must produce explicit state and recoverable errors. Usage descriptions and entitlements do not grant
consent. Test resampling, channel identity, drift, hot-swap, and a 30-minute real/replay soak.

`ReplaySource` reads bundled 16 kHz mono PCM16 WAVE fixtures and emits the same frame contract in real
time or immediate test mode. Debug builds expose English and Turkish two-channel runs in the Developer
menu. Replay has no capture permissions, network calls, persistence, or real meeting data.
