# 13 - Native UI behavior

Reconstructed on 2026-10-02. Visual styling is defined in docs/Design.md only.

## Foundation windows

The main app opens a native workspace with sidebar navigation to overview/meetings, knowledge base,
and settings. A synthetic sample meeting can be inspected without signing in or granting permissions.
Its sample status remains visible in both list and detail. Copying sample output is explicit and
must copy the selected sample text. Empty KB and unavailable account features explain their state.

The menu bar item offers opening the app, settings, and quitting. Starting recording is unavailable
until capture, consent, and service authorization are implemented. Launch never requests permissions
or starts capture. Closing a window does not secretly record or upload anything.

Settings use English by default and offer Turkish. Selection persists on the device. Every product
string uses the catalog. A debug-only Gallery displays the five base components and their states;
release builds exclude the Gallery entry point.

Account Settings supports email Magic Link and prepared Apple/Google entry points. Busy, check-email,
connected, unavailable, and generic failure states remain textual and do not expose provider errors.
The sidebar identifies a connected account without displaying personal information. Opening a valid
application callback completes PKCE; all other callback routes are rejected before network access.

## Accessibility and keyboard behavior

Use native buttons, inputs, and toggles, semantic headings, accessible names for icon controls,
and keyboard navigation. Disabled actions must have a nearby explanation. Selected state has a
non-color cue. Respect Reduce Motion and Reduce Transparency. Verify both locales for clipping.

## Future live meeting UI

Before capture, show informed consent explaining both audio channels and cloud processing. Show
permission state and capture state separately. The live overlay is a non-activating NSPanel with
drag/resize, dismiss/pin/copy, rate-limited cards, and explicit capture status. Overlay behavior,
shortcuts, and supported full-screen cases require a Phase 2 spec and tests. Do not claim universal
screen-share invisibility. Post-meeting editing and KB upload land in their phases.

P1-12 adds the native live meeting workspace and menu bar start/stop controls. The view renders
interim and final transcript segments with timestamps and a listening status indicator. Controls are
disabled until consent and injectable capture/transcription services are ready; the local preview
does not request permissions or record. The floating insight overlay remains a Phase 2 feature.

P1-13 adds a per-meeting consent sheet before recording. It explains microphone and system audio
capture, cloud transcription, and the user's control. Confirmation is held in memory for the active
meeting only and is cleared when recording stops. The backend token request continues to require the
same positive `consentConfirmed` assertion.
