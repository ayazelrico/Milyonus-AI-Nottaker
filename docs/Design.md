# Native visual design

Adapted on 2026-10-02 from the supplied root design.md, using visual styling only. This is not a
website specification. Native behavior is specified in docs/13. No Interviewer copy, cookie UI,
React stack, routes, analytics, or marketing layouts are inherited.

## Palette and surfaces

Pure black #000000 is the canvas. Brand blue is exactly #2E6BFF; cyan #5CC8FF is a secondary accent.
White is the primary foreground. Main panels use flat charcoal surfaces with restrained gray borders
and no decorative gradients. Blue borders identify selection and blue is reserved for active controls
and meaningful emphasis. Use semantic connection, warning, and error colors;
never make color the only status cue. Recording red and connected green are distinct states.

Readable native text must use sufficient contrast on its actual composited surface. Do not reuse
the website's low-opacity copyright and decorative labels as essential app text. Reduce Transparency
uses opaque surfaces. The foundation is brand-dark; a future light palette requires a separate spec.

## Typography

Inter Tight is the preferred UI font; Instrument Serif italic is reserved for expressive titles.
Use system fonts as disclosed fallbacks until distributable font files are bundled. Native body,
caption, heading, and display roles must be centralized in DesignSystem. Avoid web viewport sizes.

The supplied silver Milyonus wordmark appears at the upper-left of the native sidebar. It is bundled
as a local app resource, includes an accessibility label, and is paired with a small product descriptor.

## Geometry and components

Use a consistent spacing scale, soft card radii, pill-shaped primary actions where appropriate,
and thin borders. Native fields and toggles retain clear keyboard focus and accessibility labels.
Define all sizes, colors, fonts, spacing, and radii in DesignSystem rather than feature views.

Five base components: button, text field, card, status indicator, toggle. Native state feedback must
cover enabled/disabled, hover where applicable, keyboard focus, pressed, and busy/unavailable states.
SF Symbols provide native action icons; brand mark assets are decoration and must not replace labels.

## Motion

Keep state transitions brief and functional. Disable nonessential transitions with Reduce Motion.
No looping decorative animation, video backdrop, or recording-like pulse appears in the sample app.
