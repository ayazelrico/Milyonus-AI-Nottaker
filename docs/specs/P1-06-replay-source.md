# P1-06 - Replay source and fixtures

Status: completed on 2026-10-04. STT and transcript replay remain in P1-08 through P1-10.

## Goal

Provide deterministic microphone and system-audio sources for repeatable development without OS
capture permissions, cloud calls, or real meeting data. Bundle short synthetic English and Turkish
meeting fixtures and expose them through a debug-only Developer menu.

## Plan

1. Add an `AudioSource` implementation that reads validated 16 kHz mono PCM16 WAVE resources.
2. Emit 20 ms frames with channel identity and contiguous timestamps in real time or immediately.
3. Bundle one microphone and one system fixture for English and Turkish.
4. Add a debug-only Run replay menu with English and Turkish choices and visible run status.
5. Test resource validity, channels, timestamps, metrics, missing data, and active-session rejection.

## Boundaries

- Fixtures are synthetic speech generated for this repository and contain no personal or meeting data.
- Replay never requests capture permissions, records audio, connects to a provider, or persists output.
- The menu and coordinator are excluded from release builds.
- Replay supplies audio frames only. Provider transcripts, assembly, and persistence remain later tasks.

## Fixture inventory

The scripts below are original test copy written for Milyonus and rendered with macOS synthetic
voices. Each language has separate microphone and system speakers so later STT work can keep channel
identity intact.

| Resource | Synthetic script |
|---|---|
| `en-microphone.wav` | We should send the project update on Friday. I will draft the email and share it this afternoon. |
| `en-system.wav` | That works. Please include the launch risks and assign an owner to every action item. |
| `tr-microphone.wav` | Proje güncellemesini cuma günü göndermeliyiz. E-postayı hazırlayıp bu öğleden sonra paylaşacağım. |
| `tr-system.wav` | Uygun. Lütfen lansman risklerini ekle ve her aksiyon maddesine bir sorumlu ata. |

The committed files are WAVE PCM, one channel, signed 16-bit little-endian, and 16 kHz. They are
short development fixtures, not a quality benchmark. P1-09 owns the licensed EN/TR bake-off set.

## Acceptance

- All four bundled fixtures decode as mono signed PCM16 at 16 kHz.
- Frames use the selected channel, 20 ms chunks, contiguous monotonic timestamps, and bounded output.
- English and Turkish two-channel replays can run from the Developer menu.
- Swift build, tests, lint, formatting, bundle smoke tests, and CI pass.
