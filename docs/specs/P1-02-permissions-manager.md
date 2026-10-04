# P1-02 - Permissions manager

Status: implementation in progress.

## Goal

Provide one protocol-backed source of truth for microphone, screen/system-audio, and notification
authorization. Show current status in Settings, request each permission only after an explicit user
action, open the matching macOS Settings pane after denial, and expose a restart action when macOS
does not apply newly granted screen-capture access to the running process.

## Plan

1. Add Sendable permission values and a `PermissionService` protocol to `Shared`.
2. Implement Apple-framework adapters in a `Permissions` module, including request history for the
   screen-capture API because Core Graphics does not expose an undetermined state.
3. Refresh status when the app becomes active without requesting anything at launch.
4. Add localized Settings rows with request, open-settings, and restart actions.
5. Unit test state mapping, explicit requests, request history, and restart-required behavior with
   deterministic fakes. Never invoke a real permission prompt in CI.

## Boundaries

- OS authorization is separate from per-meeting participant consent.
- Granting a permission does not start capture, create a meeting, or call a provider.
- P1-03 owns ScreenCaptureKit capture. P5 owns calendar authorization. P6 owns full onboarding.
- The app does not claim a permission is granted unless the corresponding Apple API reports it.

## Acceptance

- Launch and passive refresh never display a permission prompt.
- Every request follows a visible user action and returns a typed status.
- Denied permissions link to the relevant macOS Settings pane.
- A stale screen-capture grant is represented as restart required and offers a controlled relaunch.
- English source strings and Turkish translations ship together.
