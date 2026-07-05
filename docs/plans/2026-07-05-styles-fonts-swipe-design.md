# Design: swipe-to-close, font selection, text styles

Covers GitHub issues #1 (swipe close), #2 (text style selection), #3 (font selection).

## Goals

- Close the marquee screen with a swipe, not just a tap (#1).
- Pick a font from a curated shortlist, previewed in the picker (#3).
- Pick a text style — Solid / Outline / Dashed outline / Striped — previewed in the picker (#2).
- Italic as an independent toggle that stacks on any style.
- A live preview strip in Settings that is pixel-identical to the real marquee.

## Architecture

One rendering primitive drives both the marquee and every preview:

- **Glyph path builder** (CoreText): `(text, font)` → `CGPath` of glyph outlines + content size.
  Replaces `measureWidth` in `MarqueeView` — shape and width come from the same source.
  Results cached (`NSCache`) keyed by text/font/size/italic, so the 120 Hz `TimelineView`
  loop never rebuilds paths.
- **`StyledText`** (SwiftUI `Canvas`): draws the path per style:
  - *Solid* — fill (current look)
  - *Outline* — stroke
  - *Dashed outline* — stroke with dash pattern
  - *Striped* — clip to path, draw horizontal lines
  - *Italic* — skew transform applied to the path (works for every font uniformly)
- **`MarqueeFont`** enum: curated shortlist (SF, SF Rounded, Helvetica Neue, Georgia,
  Avenir Next, Menlo, American Typewriter, Futura, Chalkboard).
- **`MarqueeStyle`** enum: the four styles above.

## Settings UX

- **Text** section: existing field, All caps.
- **Appearance** section: live preview strip on top (user's text or "Preview", drawn with
  chosen font/style/colors), then *Font* row → picker list with each name in its own font,
  *Style* row → picker list with each option drawn in its style, then the *Italic* toggle and the two color pickers. Pickers auto-dismiss on selection.
- Persistence: `@AppStorage` — `fontName`, `textStyle`, `italic`.

## Marquee screen

- `Text` label replaced by `StyledText`; RTL logic, carousel math, and 120 Hz animation
  unchanged; text width now comes from the glyph path (accounts for stroke padding).
- Dismiss: existing tap **plus** any swipe ≥ 80 pt (device orientation is locked while the
  phone is physically held sideways, so "down" is ambiguous — any direction counts) (#1).
