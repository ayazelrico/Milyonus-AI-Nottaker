# Phase 1 manual acceptance checklist

Run on a real Mac (macOS 14 or newer) with the signed bundle from `scripts/bundle-app.sh`. Use a stable
signing identity, otherwise TCC permissions may not persist between builds (see `docs/18`).
Never record real meetings for these tests. Use a test video or a second device playing synthetic speech.

Record the result, date, macOS version, device model, and build hash in the table at the end. Tick the
matching roadmap task only after every step for that task passes.

## Setup

```sh
python3 scripts/generate-localizations.py
swift build --package-path app && swift test --package-path app
bash scripts/bundle-app.sh debug
codesign -dv "build/Milyonus Nottaker.app" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier"
open "build/Milyonus Nottaker.app"
```

Reset permissions before a clean run: `tccutil reset All <bundle identifier>`.

## P1-01 Microphone capture

1. Launch the app. Confirm no permission prompt and no mic indicator appears (nothing starts on launch).
2. Start a test meeting after granting consent. Confirm the macOS mic indicator appears.
3. Speak. Confirm frames flow (live transcript window or debug counters). Output must be 16 kHz mono PCM16.
4. Hot-swap: while capturing, unplug or switch the input device (headset to built-in). Capture must
   restart on the new device, or end with a visible typed error. No crash, no hang.
5. Select an explicit non-default input. Confirm the chosen device is used.
6. Stop. Confirm the mic indicator disappears within 2 seconds.
7. Revoke mic permission in System Settings during capture. Confirm capture stops cleanly.

## P1-02 Permissions manager

1. Settings shows microphone, screen/system audio, and notification status accurately.
2. Each permission is requested only after pressing its button.
3. After denial, the button opens the matching System Settings pane.
4. Grant screen recording. Confirm the restart-required action appears when macOS needs it, and that
   restarting makes system audio work.
5. Quit and relaunch. Confirm statuses persist (needs a stable signing identity).

## P1-03 System audio

1. Play a video in a browser. Start capture. Confirm system audio frames flow.
2. Confirm Milyonus's own sounds are excluded (no feedback loop).
3. Per-app filter: restrict to one app and confirm other apps are silent in the stream.
4. Output is 16 kHz mono PCM16 with monotonic timestamps.
5. Stop and confirm the screen-recording indicator disappears.

## P1-14 30-minute soak (live and replay)

1. Replay mode: run the 30-minute replay fixture. Record CPU, memory (Activity Monitor or `top -pid`),
   dropped frames, and reconnect count at 0, 10, 20, and 30 minutes.
2. Live mode: play a 30-minute synthetic recording through speakers and capture mic plus system audio.
3. Pass criteria: no crash, memory growth under 10 percent after the first 5 minutes, no unbounded
   queue, zero unexpected stream failures. Compare with `docs/reports/replay-performance-baseline.md`.
4. Save the numbers to `docs/reports/phase-1-soak.md` (metadata only, no audio or transcript text).

## P1-09 STT bake-off (needs provider accounts)

Prepare 10 synthetic or licensed recordings (EN and TR, including code switching). Run both providers,
compute WER, latency to first final, and cost per hour. Write `docs/reports/stt-bakeoff.md`, pick the
primary, and implement the secondary adapter behind the `Shared` STT protocol.

## Results log

| Task | Date | macOS | Device | Build | Result | Notes |
|---|---|---|---|---|---|---|
| P1-01 | | | | | not run | |
| P1-02 | | | | | not run | |
| P1-03 | | | | | not run | |
| P1-09 | | | | | not run | |
| P1-14 | | | | | not run | |
