# Marquee

An iOS app that turns your phone into a scrolling LED-style marquee: type some text, hand the phone to someone, and let them read it from a distance.

## How it works

**Settings screen** — text input, text color, background color, scroll speed, an "all caps" toggle, and a start button. All settings persist between launches.

**Display screen** — the text is shown at a huge size (nearly the full width of the screen), rotated sideways: the phone stays in portrait orientation while the line travels bottom to top. If the text fits entirely, it's centered and static. If not, it loops in an endless carousel with a small gap between repeats and no blank screen in between. For right-to-left scripts (Hebrew, Arabic), the direction of motion is mirrored. The screen stays awake while displaying. Tapping anywhere returns to settings.

## Technical details

- SwiftUI, no external dependencies
- Animation driven by `TimelineView(.animation)` — position is computed from elapsed time, so nothing restarts or drifts
- Text is rotated via `rotationEffect(90°)` instead of changing the system orientation — no screen "flipping"
- Settings are stored in `@AppStorage`; colors are serialized to hex

## Build

Open `Marquee.xcodeproj` in Xcode and run. Requires iOS 26+.
