# Replay performance baseline

This report records the deterministic replay baseline used before a real-device soak. It runs both
bundled English and Turkish microphone/system fixtures with `ReplayPacing.immediate`, sends every
frame through the same bounded stream contract, and appends frames to the rolling buffer. The test
fails if either channel emits no frames or if the buffer reports an eviction or timestamp
discontinuity during the fixture run.

Run it from the repository root:

```sh
bash scripts/replay-soak.sh
```

The baseline is a fast correctness and capture-pressure check. It does not replace P1-14's
30-minute real-time soak on a signed macOS build, and it does not verify provider behavior or live
network recovery. Those require a physical device, authorized microphone/system audio, and the
licensed provider fixtures tracked by P1-09.
