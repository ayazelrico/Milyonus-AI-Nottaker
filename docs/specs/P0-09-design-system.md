# P0-09 - Native design system

Status: implementation authorized by the owner on 2026-10-02.

## Goal and requirements

Create a native, accessible brand-dark UI using visual styling only from the supplied design.md. Covers FR-01, FR-02, and NFR-06 accessible UI.

## Plan

1. Centralize black canvas, blue/cyan accents, readable foregrounds, typography, spacing, radii, and motion in DesignSystem.
2. Provide button, text field, card, status indicator, and toggle components with native keyboard/accessibility behavior.
3. Build a debug-only Gallery and a useful application shell with explicit sample data, meeting detail, setup status, and preferences.
4. Use system font fallbacks until licensed brand font files are bundled and verified. Do not download fonts or claim they are installed without permission.
5. Validate layout, reduced motion/transparency, English/Turkish content, and deterministic token tests.

## Scope and risks

Website copy, Interviewer product behavior, web stack, routing, cookie banners, and marketing animations are excluded. The shell must never fabricate live capture, authentication, billing, or connected-provider status. Gallery completeness and font integration are tracked separately in the roadmap.
