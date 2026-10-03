# Milyonus Landing Page — Design System Documentation

> Complete style and design reference for **www.milyonus.com**
> Stack: React 19 + TypeScript + Vite + Tailwind CSS + Framer Motion

---

## 1. Technology & Tooling

| Layer | Tool | Notes |
|---|---|---|
| Framework | React 19.2 + React Router 7 | SPA, client-side routing |
| Build | Vite | `vite build` + `tsc -b` |
| Styling | Tailwind CSS 3 + inline `style={{}}` | Tailwind for layout utilities, inline styles for design tokens |
| Animations | Framer Motion 13 | Entry, hover, scroll-triggered animations |
| Icons | Lucide React | Line icons (`ArrowUpRight`, `Menu`, `X`, `Plus`, `ShieldCheck`, etc.) |
| PostCSS | Tailwind + Autoprefixer | Standard pipeline |
| Video | HLS.js | Hero background video with HLS streaming |
| Analytics | Vercel Analytics + Speed Insights | Consent-gated |
| Monitoring | Sentry | Error tracking |

---

## 2. Color Palette

### Brand Blues

| Token | Hex | Usage |
|---|---|---|
| `brand-50` | `#EAF1FF` | Lightest tint (unused in dark theme) |
| `brand-200` | `#9DBBFF` | — |
| `brand-400` | `#4C86FF` | — |
| `brand-500` | `#2E6BFF` | **Primary brand blue** — buttons, gradients, accents, chart lines, selection highlight |
| `brand-600` | `#1746C8` | Darker brand accent |
| `brand-700` | `#0F3399` | — |
| `brand-900` | `#061C5E` | Deepest navy |
| `cyanite` | `#5CC8FF` | Secondary accent — competency tree glow, active tab icons, gradient endpoints |

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `--pass` | `#22C55E` | Passed/success status, live indicator dots |
| `--review` | `#F5A524` | In-review/warning status |
| `ink` | `#000000` | Background color, text on light surfaces |
| Foreground | `#FFFFFF` | Primary text color |

### Functional Opacity Scale (white-based)

| Opacity | Usage |
|---|---|
| `rgba(255,255,255,0.95)` | Primary white text, active dots |
| `rgba(255,255,255,0.80)` | Nav link text, secondary text |
| `rgba(255,255,255,0.70)` | Scorecard labels |
| `rgba(255,255,255,0.65)` | Card body text, lead paragraphs |
| `rgba(255,255,255,0.60)` | Section subtitles, hero kicker |
| `rgba(255,255,255,0.55)` | FAQ answers, muted body text, social icons |
| `rgba(255,255,255,0.50)` | Section eyebrows |
| `rgba(255,255,255,0.45)` | Locked consent label |
| `rgba(255,255,255,0.35)` | Capability numbers, secondary labels |
| `rgba(255,255,255,0.28)` | Footer copyright, inactive wave bars |
| `rgba(255,255,255,0.14)` | Borders on buttons, cards, dividers |
| `rgba(255,255,255,0.10)` | Card borders, glass panel borders |
| `rgba(255,255,255,0.08)` | Grid gap backgrounds, card backgrounds |
| `rgba(255,255,255,0.06)` | Ghost button backgrounds, subtle dividers |
| `rgba(255,255,255,0.03)` | Social icon backgrounds |

### Blue Opacity Scale (brand-based)

| Value | Usage |
|---|---|
| `rgba(46,107,255,0.55)` | Active tab borders, closing section glow |
| `rgba(46,107,255,0.40)` | Footer CTA border |
| `rgba(46,107,255,0.35)` | Footer divider line |
| `rgba(46,107,255,0.28)` | Trust icon borders |
| `rgba(46,107,255,0.22)` | Hover trust icons |
| `rgba(46,107,255,0.15)` | Footer CTA background |
| `rgba(46,107,255,0.12)` | Trust icon background |
| `rgba(46,107,255,0.10)` | Active platform tab background |
| `rgba(46,107,255,0.08)` | Active consent checkbox background |
| `rgba(74,127,255,0.7)` | Footer section heading color |
| `rgba(74,127,255,0.6)` | Footer section heading alternate |

---

## 3. Typography

### Font Families

| Token | Family | Weight | Usage |
|---|---|---|---|
| `font-heading` | "Inter Tight", system-ui, sans-serif | 300–700 | Headlines (upright), body text, UI labels, buttons, navigation |
| `font-serif` | "Instrument Serif", Georgia, serif | 400 (italic) | Accent headlines (italic), card titles, large display text |
| `font-sans` | Same as `font-heading` | — | Default body (alias) |

### Loading

Fonts loaded via Google Fonts with `preconnect`:
```
Inter Tight: wght@300;400;500;600;700
Instrument Serif: ital@0;1
```

### Type Scale

| Element | Size | Weight | Line Height | Letter Spacing | Font |
|---|---|---|---|---|---|
| Hero H1 (top) | `clamp(46px, 8.6vw, 108px)` | 400 | 0.95 | -0.02em | `font-heading` |
| Hero H1 (accent) | Same as above | 400 italic | 0.95 | -0.02em | `font-serif` |
| Section H2 (top) | `clamp(38px, 5.4vw, 72px)` | 400 | 1.0 | -0.02em | `font-heading` |
| Section H2 (accent) | Same as above | 400 italic | 1.08 | -0.02em | `font-serif` |
| PageShell H1 | `clamp(40px, 7vw, 84px)` | 400 | 0.98 | -0.02em | Mixed |
| Card H3 | 26px | 400 italic | — | — | `font-serif` |
| Persona name | 34px | 400 italic | — | — | `font-serif` |
| FAQ title | `clamp(38px, 5vw, 64px)` | 400 italic | 1.05 | — | `font-serif` |
| Closing H2 | `clamp(34px, 5vw, 64px)` | 400 | 1.05 | -0.02em | Mixed |
| Footer wordmark | `clamp(52px, 8vw, 100px)` | 400 italic | 0.92 | -0.03em | `font-serif` |
| Eyebrow | 12px | 500 | — | 2px | `font-heading`, uppercase |
| Section subtitle | 16px | 400 | 1.6 | — | `font-heading` |
| Body text (cards) | 13px | 400 | 1.6 | — | `font-heading` |
| Nav links | 14px | 400 | — | — | `font-heading` |
| Button text | 13–15px | 500 | — | — | `font-heading` |
| FAQ question | 17px | 400 | 1.4 | — | `font-heading` |
| FAQ answer | 14.5px | — | 1.7 | — | `font-heading` |
| Scorecard big number | `clamp(34px, 4vw, 42px)` | 400 | — | -1px | `font-heading` |

### Headline Pattern

Every section follows a **two-line headline** pattern:
1. **Line 1** — Upright sans (`font-heading`), weight 400
2. **Line 2** — Italic serif (`font-serif`), weight 400

This pairing appears in Hero, SectionHeader, PageShell, Closing, Footer, and FAQ.

### Gradient Text

The accent (serif italic) line in Hero and PageShell uses a gradient text effect:
```css
background: linear-gradient(180deg, #FFFFFF 25%, #A9B4C6 100%);
-webkit-background-clip: text;
background-clip: text;
color: transparent;
```

---

## 4. Layout & Spacing

### Content Widths

| Context | Max Width |
|---|---|
| Main content sections | `1200px` |
| Hero bottom rail | `1400px` |
| FAQ | `1100px` |
| PageShell header | `900px` |
| Subtitle text block | `620px` |
| Lead paragraph | `640px` |

### Section Padding Pattern

Every section follows this consistent padding:
```css
padding: clamp(64px, 8vw, 96px) clamp(20px, 4vw, 48px);
```
This means:
- **Vertical**: 64px → 96px (scales with viewport)
- **Horizontal**: 20px → 48px (scales with viewport)

### Grid System

| Component | Grid | Gap |
|---|---|---|
| Agent cards | 1 col → 3 col (`lg:flex-row`) | 16px |
| Benefits grid | 1 → 2 → 4 col (`sm:grid-cols-2 lg:grid-cols-4`) | 16px |
| Capabilities | 1 → 2 → 3 col (`sm:grid-cols-2 lg:grid-cols-3`) | 1px (border-separated) |
| Trust items | 1 → 2 → 3 col | 1px |
| Personas | 1 → 3 col (`md:grid-cols-3`) | 16px |
| Footer links | 1 → 3 col (`sm:grid-cols-3`) | `clamp(40px, 5vw, 72px)` |

### Responsive Breakpoints (Tailwind defaults)

| Breakpoint | Min Width | Usage |
|---|---|---|
| `sm` | 640px | Grid column shifts |
| `md` | 768px | Login link visibility, footer layout |
| `lg` | 1024px | Desktop nav, multi-column layouts |

---

## 5. Component Design Patterns

### Cards

**Border Radius**: `24px` (custom `rounded-card` token)

**Three card styles**:

1. **Glass cards** (scorecard, agent transcript):
   ```css
   border-radius: 20px;
   border: 1px solid rgba(255,255,255,0.20);
   background: rgba(255,255,255,0.10);
   backdrop-filter: blur(56px);
   padding: 24px 28px;
   ```

2. **Image cards** (benefits, intelligence):
   - Full-bleed background image
   - Gradient overlay: `linear-gradient(180deg, rgba(3,8,24,0.25) 0%, rgba(3,8,24,0.72) 52%, rgba(2,5,14,0.96) 100%)`
   - Text positioned absolutely at bottom

3. **Grid cells** (capabilities, trust):
   - 1px gap between cells (using `gap: 1` with bg color showing through)
   - Container: `background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.08); border-radius: 24px; overflow: hidden`
   - Each cell: `background: #000; padding: 30px 28px 34px`

### Card Footer Pattern

Repeated across Agent and Intelligence sections:
```tsx
<h3 className="font-serif" style={{ fontStyle: "italic", fontSize: 26, fontWeight: 400, color: "#fff" }}>
  {title}
</h3>
<p className="font-heading" style={{ fontSize: 13, color: "rgba(255,255,255,0.65)", lineHeight: 1.6 }}>
  {body}
</p>
```

### Buttons

**Primary (CTA)**:
```css
background: #fff;
color: #000;
font-size: 14-15px;
font-weight: 500;
padding: 10px 20px;  /* or 8px 8px 8px 24px with icon */
border-radius: 9999px;  /* pill shape */
```
Often includes a black circle icon container: `width: 24-26px; background: #000; border-radius: 9999px` with a white `ArrowUpRight` icon.

**Ghost / Secondary**:
```css
background: rgba(255,255,255,0.06);
border: 1px solid rgba(255,255,255,0.14);
color: rgba(255,255,255,0.80);
padding: 10px 16px;
border-radius: 9999px;
```

**Blue Outline (Footer CTA)**:
```css
background: rgba(46,107,255,0.15);
border: 1.5px solid rgba(46,107,255,0.4);
color: #8FB6FF;
padding: 14px 28px;
border-radius: 9999px;
```

### Navbar

- **Fixed** at top, z-index 50
- **Scroll behavior**: transparent → `rgba(0,0,0,0.62)` with `backdrop-filter: blur(18px)` and subtle bottom border
- **Desktop nav pill**: Centered absolutely, `background: rgba(20,22,28,0.72)`, `backdrop-filter: blur(12px)`, `border: 1px solid rgba(255,255,255,0.10)`, `border-radius: 9999px`
- **Nav items**: 14px, weight 400, hover bg `rgba(255,255,255,0.10)`
- **Mobile menu**: Full-screen overlay, `rgba(0,0,0,0.94)`, nav items in `font-serif` at 40px italic

### Section Header (Reusable)

`SectionHeader` component used across sections:
1. **Eyebrow**: 12px, weight 500, uppercase, letter-spacing 2px, `rgba(255,255,255,0.50)`
2. **Title**: Two-part (heading + accent), fluid size `clamp(38px, 5.4vw, 72px)`
3. **Subtitle**: 16px, `rgba(255,255,255,0.60)`, max-width 620px, centered
4. **Entrance animation**: blur(12px) + y:30 → blur(0) + y:0, 0.8s easeOut

---

## 6. Background & Visual Effects

### Global Background

Pure black (`#000`) throughout. Every section, every page.

### Hero Background

- **Video backdrop**: HLS-streamed video with poster fallback
- **Gradient overlay** on top of video:
  ```css
  linear-gradient(to bottom,
    rgba(0,0,0,0.62) 0%,
    rgba(0,0,0,0.34) 34%,
    rgba(0,0,0,0.58) 62%,
    rgba(0,0,0,0.88) 100%)
  ```

### Light Ray Animation (CSS fallback)

```css
@keyframes ray-drift {
  0%   { transform: translateX(-1.5%) scaleY(1);    opacity: 0.82; }
  50%  { transform: translateX(1.5%) scaleY(1.05);   opacity: 1;    }
  100% { transform: translateX(-1.5%) scaleY(1);    opacity: 0.82; }
}
/* Duration: 12s ease-in-out infinite */
```

### Card Radial Gradients

Each Agent card has a unique radial gradient background:
- **Card 1**: `radial-gradient(110% 80% at 20% 0%, #14346E 0%, #0A1B44 42%, #05080F 100%)`
- **Card 2**: `radial-gradient(120% 90% at 50% 8%, #2E6BFF 0%, #123694 38%, #060C22 100%)`
- **Card 3**: `radial-gradient(100% 70% at 50% 100%, #10224F 0%, #070B18 55%, #04060D 100%)`

### Interview Card

- **3D perspective tilt**: `perspective: 1200`, rotates toward mouse cursor
- **Complex layered background**:
  1. Base radial gradient (brand blue centered)
  2. Soft-light linear gradient overlay
  3. Specular highlight radial gradient
  4. Inset box-shadow for glass edge
- **Box shadow**: `0 40px 100px rgba(0,0,0,0.55), 0 8px 24px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.18)`

### Grid Pattern (Card 3)

Subtle repeating grid overlay:
```css
repeating-linear-gradient(0deg, rgba(255,255,255,0.035) 0 1px, transparent 1px 34px),
repeating-linear-gradient(90deg, rgba(255,255,255,0.035) 0 1px, transparent 1px 34px)
```

### Closing Section Gradient

```css
radial-gradient(120% 130% at 50% -20%,
  rgba(46,107,255,0.55) 0%,
  rgba(11,46,147,0.32) 34%,
  rgba(4,8,22,0.9) 68%,
  #03050C 100%)
```

### Footer Glow Effects

- **Top line**: `linear-gradient(to right, transparent, rgba(46,107,255,0.5), transparent)`
- **Radial backdrop**: `radial-gradient(ellipse 80% 100% at 50% 0%, rgba(30,70,220,0.13) 0%, transparent 70%)`
- **Watermark**: PNG at 7% opacity with `mix-blend-mode: screen`

---

## 7. Animations & Motion

### Framer Motion Defaults

**Standard easing**: `[0.22, 1, 0.36, 1]` (custom easeOutQuint)

| Pattern | Config | Usage |
|---|---|---|
| Fade in + slide up | `opacity: 0, y: 30-40 → opacity: 1, y: 0` | Cards, sections |
| Fade in + slide left/right | `opacity: 0, x: ±60 → opacity: 1, x: 0` | Intelligence panels |
| Blur reveal | `opacity: 0, filter: blur(12px), y: 30 → clear` | Section headers |
| Scale on hover | `whileHover: { scale: 1.04 }` | CTA buttons |
| Scale on tap | `whileTap: { scale: 0.97 }` | Buttons |
| Staggered children | `delay: 0.1 * index` to `0.15 * index` | Grid items, nav items |

### Scroll-Triggered Animations

Using `useInView` with `{ once: true, margin: "-100px" }`:
- Elements animate when they enter viewport (100px before becoming visible)
- Each animation fires only once

### Pulsing Ring (Hero CTA)

```tsx
animate={{ scale: [1, 1.28, 1], opacity: [0.55, 0, 0.55] }}
transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
```

### Live Indicator Dot

```tsx
animate={{ opacity: [1, 0.2, 1] }}
transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
/* Color: #E1483C (red) */
```

### CSS Animations

| Name | Duration | Usage |
|---|---|---|
| `marquee` | 14s linear infinite | Client logo scroll |
| `marquee-slow` | 34s linear infinite | Alternate marquee speed |
| `story-fill-1/2` | 6s linear infinite | Interview card progress bars |
| `ray-drift` | 12s ease-in-out infinite | Hero light rays |
| `glow-pulse` | 7s ease-in-out infinite | Background glow |
| `wave` | 1.1s ease-in-out infinite | Voice waveform bars |

### CountUp Animation

Numbers animate from a starting value to target when scrolled into view (custom `useCountUp` hook).

### Competency Tree

SVG paths drawn with `pathLength: 0 → 1` animation, with glowing dots traveling along paths using `<animateMotion>`.

### `prefers-reduced-motion`

All animations disabled with `animation-duration: 0.001ms !important`.

---

## 8. Interactive Patterns

### Hover States

| Element | Effect |
|---|---|
| Nav links | Background `rgba(255,255,255,0.10)` |
| CTA buttons | `scale: 1.04` |
| Benefits cards | Image scales to 1.07, overlay lightens, text lifts 6px |
| Grid cells (Capabilities, Trust) | Background darkens to `#060d1c`, blue top accent line reveals |
| Footer social icons | Border turns blue, bg blue tint, lifts 2px, blue shadow |
| Footer links | Color to white, underline grows from left (0 → 100% width) |
| FAQ questions | Text brightens from 0.78 to 1.0 opacity |
| Persona cards | Radial gradient with accent color appears, waveform activates |

### Tooltip Component

- Background: `rgba(6,12,28,0.97)`
- Border: `1px solid rgba(92,200,255,0.22)`
- Rounded: 10px
- Backdrop blur: 16px
- Shadow: `0 8px 32px rgba(0,0,0,0.5)`
- Entry: scale 0.94 → 1, 0.14s easeOut

### FAQ Accordion

- Toggle icon: Plus → rotates 45° (becomes X)
- Body: height 0 → auto with opacity transition
- Easing: `[0.22, 1, 0.36, 1]`, 0.4s

### Platform Tabs

- Inactive: transparent bg, `rgba(255,255,255,0.10)` border
- Active: `rgba(46,107,255,0.10)` bg, `rgba(46,107,255,0.55)` border, cyan arrow icon
- Image transition: `AnimatePresence mode="wait"`, crossfade with subtle scale

### Interview Card Q&A Rotation

- Auto-rotates every 4.6s
- Dot navigation: active dot width 20px, inactive 6px
- Pauses 10s on user interaction, then resumes
- Transition: blur(8px) + y offset, 0.6s

---

## 9. Glassmorphism & Material

The site heavily uses **glassmorphism** for elevated UI elements:

```css
/* Standard glass panel */
background: rgba(255,255,255,0.10);
backdrop-filter: blur(56px);
-webkit-backdrop-filter: blur(56px);
border: 1px solid rgba(255,255,255,0.20);
border-radius: 20px;

/* Navbar glass */
background: rgba(20,22,28,0.72);
backdrop-filter: blur(12px);
border: 1px solid rgba(255,255,255,0.10);

/* Consent banner glass */
background: rgba(10,12,20,0.86);
backdrop-filter: blur(28px);
border: 1px solid rgba(255,255,255,0.14);
border-radius: 22px;
box-shadow: 0 24px 70px rgba(0,0,0,0.6);

/* Scrolled navbar glass */
background: rgba(0,0,0,0.62);
backdrop-filter: blur(18px);
border-bottom: 1px solid rgba(255,255,255,0.07);
```

---

## 10. Brand Assets

### Logo Variants

| Asset | Path | Usage |
|---|---|---|
| Mark (icon) | `/assets/brand/milyonus-mark.png` | Four-point brand mark, used in cards and navigation |
| Wordmark (white) | `/assets/brand/milyonus-wordmark-white.png` | Header logo, white knockout for dark bg |
| Emblem | `/assets/brand/milyonus-emblem.png` | OG image |
| Footer watermark | `/assets/brand/milyonus-footer-watermark.png` | 7% opacity footer background |

### Favicons

- `/favicon.png` — 32×32
- `/icon-512.png` — 512×512
- `/apple-touch-icon.png` — Apple touch icon

### Meta & SEO

- Theme color: `#000000`
- OG type: `website`
- Twitter card: `summary_large_image`
- Structured data: Organization + SoftwareApplication + WebSite (JSON-LD)

---

## 11. Selection & Scrollbar

### Text Selection

```css
::selection {
  background: rgba(46,107,255,0.35);
  color: #fff;
}
```

### Custom Scrollbar

```css
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-track { background: #000; }
::-webkit-scrollbar-thumb {
  background: rgba(255,255,255,0.14);
  border-radius: 9999px;
}
```

---

## 12. Page Structure

### Landing Page (Index) Section Order

1. **Hero** — Full-viewport, video bg, headline, CTA, interview card, client logos
2. **AgentSection** — 3-column cards showcasing agent capabilities
3. **Capabilities** — 6-cell grid with numbered items
4. **Intelligence** — 2-column: live scorecard + report card
5. **Personas** — 3 agent persona cards with waveforms
6. **Platform** — Tab-based product screenshots
7. **Benefits** — 4 image cards + trust strip
8. **Trust** — 6-cell security grid with shield icons
9. **FAQ** — Split layout: title left, accordion right
10. **Closing** — CTA band with radial gradient
11. **Footer** — 3-column links, social icons, legal

### Inner Pages (PageShell)

Shared layout wrapper providing:
- Same hero background (shorter height: `clamp(420px, 62vh, 620px)`)
- Same gradient overlay (adjusted percentages)
- Same navbar
- Eyebrow + two-part headline + optional lead
- Content slot
- Closing CTA band
- Footer

---

## 13. Internationalization

- 4 locales: `/` (English), `/tr`, `/de`, `/es`
- All user-facing strings go through `t()` from `useLocale()`
- Copy centralized in `src/lib/site.ts`
- Route structure: `/{locale}/{page}`

---

## 14. Consent & Privacy

### Consent Banner Design

- Appears after 900ms delay on first visit
- Two states: compact banner → expanded preferences panel
- Cookie icon: `rgba(46,107,255,0.16)` bg, `#8FB6FF` icon
- Custom checkbox: 20×20px, border-radius 6px, brand blue when active
- Categories: Necessary (locked), Analytics, Marketing

### Google Consent Mode v2

Configured in `index.html` — all optional storage starts `denied`, updated after user choice.

---

## 15. CSS Design Tokens (`:root`)

```css
:root {
  --background: 0 0% 0%;          /* HSL black */
  --foreground: 0 0% 100%;        /* HSL white */
  --card: 0 0% 4%;                /* Near-black card bg */
  --card-foreground: 0 0% 100%;
  --primary: 222 100% 59%;        /* Brand blue in HSL */
  --primary-foreground: 0 0% 100%;
  --muted: 0 0% 12%;
  --muted-foreground: 0 0% 62%;
  --border: 0 0% 100%;
  --radius: 0.5rem;
  --brand-500: #2E6BFF;
  --brand-600: #1746C8;
  --brand-900: #061C5E;
  --brand-cyan: #5CC8FF;
  --pass: #22C55E;
  --review: #F5A524;
}
```

---

## 16. Key Design Principles

1. **Dark-first**: Pure black background throughout, never gray
2. **Glassmorphism**: Frosted glass panels with backdrop-filter blur
3. **Dual typography**: Sans headlines paired with italic serif accents
4. **Brand blue (#2E6BFF)** as the sole chromatic anchor; cyan (#5CC8FF) as secondary
5. **Subtle borders**: Always `rgba(255,255,255,0.10–0.20)`, never solid white
6. **Scroll-triggered once**: Animations fire on first scroll into view, never replay
7. **Pill-shaped buttons**: `border-radius: 9999px` on all CTAs
8. **Consistent padding**: `clamp(64px, 8vw, 96px) clamp(20px, 4vw, 48px)` across sections
9. **Radial gradients**: Each section/card has its own blue-to-dark radial gradient
10. **Minimal icons**: Lucide line icons at 12–18px, stroke 1.8–2.5
11. **No light mode**: The site is exclusively dark-themed
12. **Accessibility**: `prefers-reduced-motion` respected, proper ARIA labels, semantic HTML
