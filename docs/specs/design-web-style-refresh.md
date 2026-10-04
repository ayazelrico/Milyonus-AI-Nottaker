# Native brand style refresh

## Goal

Align the existing macOS workspace with the visual language in the owner-provided reference screenshot
while preserving the app's native behavior, navigation, copy, consent model, and feature scope.

## Approved visual changes

- Use pure black for the window and sidebar canvas.
- Use flat charcoal panels, thin neutral borders, restrained blue selection outlines, and generous spacing.
- Reduce cyan usage to secondary accents and use brand blue for active controls and meaningful emphasis.
- Use Inter Tight for interface text and Instrument Serif italic for expressive display text.
- Place the supplied silver Milyonus wordmark at the upper-left of the sidebar with the product descriptor.
- Keep essential text at accessible contrast levels even when the reference uses lower contrast decoration.

## Excluded changes

The reference website contributes visual direction only. Its information architecture, features, copy,
calendar layout, organization controls, routes, web stack, and product behavior are not part of this change.

## Acceptance criteria

- The workspace, meetings, knowledge base, component gallery, and settings screens use shared refreshed tokens.
- Selection, focus, status, and primary actions remain visually distinct and accessible.
- The Milyonus wordmark is visible at the upper-left and is present in the packaged app resource bundle.
- Swift build, tests, localization checks, repository checks, lint, formatting, bundle, and smoke checks pass.
