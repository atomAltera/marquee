//
//  TextRendering.swift
//  Marquee
//

import SwiftUI
import CoreText

// MARK: - Font choices

/// Curated shortlist of heavy open-source display fonts (SIL OFL), bundled
/// with the app. All of them cover both Latin and Cyrillic.
enum MarqueeFont: String, CaseIterable, Identifiable {
    case system
    case montserrat
    case unbounded
    case rubik
    case exo
    case oswald
    case russo
    case play

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "SF (Default)"
        case .montserrat: return "Montserrat"
        case .unbounded: return "Unbounded"
        case .rubik: return "Rubik"
        case .exo: return "Exo 2"
        case .oswald: return "Oswald"
        case .russo: return "Russo One"
        case .play: return "Play"
        }
    }

    /// PostScript name of the bundled font file (nil for the system font).
    private var postScriptName: String? {
        switch self {
        case .system: return nil
        case .montserrat: return "MontserratThin-Black" // quirk of the static build; it IS the 900 weight
        case .unbounded: return "Unbounded-Black"
        case .rubik: return "RubikLight-Black" // same quirk; 900 weight
        case .exo: return "Exo2-Black"
        case .oswald: return "Oswald-Bold"
        case .russo: return "RussoOne-Regular"
        case .play: return "Play-Bold"
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .black)
        guard let name = postScriptName else { return fallback }
        return UIFont(name: name, size: size) ?? fallback
    }
}

// MARK: - Style choices

enum MarqueeStyle: String, CaseIterable, Identifiable {
    // Basics
    case solid
    case outline
    case dashedOutline
    case striped
    case inline
    // Decorative
    case neon
    case chrome
    case gold
    case extrude
    case popArt
    case gloss
    case glass
    case stencil
    case engraved
    // Animated
    case rainbow
    case fire
    case glitch

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .solid: return "Solid"
        case .outline: return "Outline"
        case .dashedOutline: return "Dashed outline"
        case .striped: return "Striped"
        case .inline: return "Inline"
        case .neon: return "Neon"
        case .chrome: return "Chrome"
        case .gold: return "Gold"
        case .extrude: return "3D Shadow"
        case .popArt: return "Pop Art"
        case .gloss: return "Glossy"
        case .glass: return "Glass"
        case .stencil: return "Stencil"
        case .engraved: return "Engraved"
        case .rainbow: return "Rainbow"
        case .fire: return "Fire"
        case .glitch: return "Glitch"
        }
    }

    /// Animated styles redraw every frame; static ones render once and
    /// only move, which is what keeps 120 Hz scrolling cheap.
    var isAnimated: Bool {
        switch self {
        case .chrome, .rainbow, .fire, .glitch: return true
        default: return false
        }
    }
}

// MARK: - Color helpers

private extension Color {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    var isDark: Bool {
        let c = rgba
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b < 0.5
    }

    /// Linear blend toward another color; `amount` 0 = self, 1 = other.
    func mixed(with other: Color, _ amount: CGFloat) -> Color {
        let a = rgba, b = other.rgba
        let t = min(max(amount, 0), 1)
        return Color(
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t
        )
    }

    func lighter(_ amount: CGFloat) -> Color { mixed(with: .white, amount) }
    func darker(_ amount: CGFloat) -> Color { mixed(with: .black, amount) }
}

// MARK: - Glyph layout

/// Converts (text, font, size, italic) into a `CGPath` of glyph outlines
/// plus metrics. The path is the single source of truth for both shape and
/// width, shared by the marquee and every preview. Instances are cached so
/// the 120 Hz animation loop never rebuilds paths.
final class GlyphLayout {
    let path: CGPath
    let ascent: CGFloat
    let descent: CGFloat
    let advance: CGFloat
    let fontSize: CGFloat

    /// Uniform padding around the glyphs so strokes, glows, and shadows are
    /// not clipped at the canvas edge. Constant across styles, so switching
    /// styles never changes the text width or carousel spacing.
    var pad: CGFloat { fontSize * 0.15 }

    var frameSize: CGSize {
        CGSize(width: advance + pad * 2, height: ascent + descent + pad * 2)
    }

    private init(text: String, font: MarqueeFont, size: CGFloat, italic: Bool) {
        let uiFont = font.uiFont(size: size)
        let attributed = NSAttributedString(string: text, attributes: [.font: uiFont])
        let line = CTLineCreateWithAttributedString(attributed)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let advance = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

        // Collect glyph outlines in text-space (y grows up, baseline at y=0).
        let outline = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            let range = CFRange(location: 0, length: count)
            CTRunGetGlyphs(run, range, &glyphs)
            CTRunGetPositions(run, range, &positions)
            for i in 0..<count {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
                let transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                outline.addPath(glyphPath, transform: transform)
            }
        }

        if italic {
            // Skew tops to the right: works uniformly for every font.
            let skew = CGAffineTransform(a: 1, b: 0, c: 0.22, d: 1, tx: 0, ty: 0)
            let skewed = CGMutablePath()
            skewed.addPath(outline, transform: skew)
            self.path = skewed
        } else {
            self.path = outline
        }

        self.ascent = ascent
        self.descent = descent
        self.advance = advance
        self.fontSize = size
    }

    // MARK: Cache

    private static let cache = NSCache<NSString, GlyphLayout>()

    static func cached(text: String, font: MarqueeFont, size: CGFloat, italic: Bool) -> GlyphLayout {
        let key = "\(text)|\(font.rawValue)|\(size)|\(italic)" as NSString
        if let layout = cache.object(forKey: key) { return layout }
        let layout = GlyphLayout(text: text, font: font, size: size, italic: italic)
        cache.setObject(layout, forKey: key)
        return layout
    }
}

// MARK: - Styled text view

/// Renders text in the chosen font and style. Used by both the marquee
/// screen and the settings previews, so what you preview is what you get.
/// `time` drives animated styles; pass 0 for a static rendition.
struct StyledText: View {
    let text: String
    let font: MarqueeFont
    let style: MarqueeStyle
    let italic: Bool
    let size: CGFloat
    let color: Color
    var time: Double = 0

    static func measure(text: String, font: MarqueeFont, size: CGFloat, italic: Bool) -> CGSize {
        GlyphLayout.cached(text: text, font: font, size: size, italic: italic).frameSize
    }

    var body: some View {
        let layout = GlyphLayout.cached(text: text, font: font, size: size, italic: italic)
        Canvas { context, _ in
            // Move origin to the baseline and flip: the glyph path lives in
            // text-space where y grows upward.
            context.translateBy(x: layout.pad, y: layout.pad + layout.ascent)
            context.scaleBy(x: 1, y: -1)
            draw(in: &context, layout: layout)
        }
        .frame(width: layout.frameSize.width, height: layout.frameSize.height)
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, layout: GlyphLayout) {
        let glyphs = Path(layout.path)
        let bounds = layout.path.boundingBox
        let lineWidth = max(1, size * 0.035)
        // Rect safely covering the glyphs, for gradient fills inside clips.
        let cover = CGRect(
            x: bounds.minX - size, y: -layout.descent - size,
            width: bounds.width + size * 2, height: layout.ascent + layout.descent + size * 2
        )

        /// Vertical shading: location 0 = top of the text, 1 = bottom.
        func vertical(_ stops: [Gradient.Stop]) -> GraphicsContext.Shading {
            .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: 0, y: layout.ascent),
                endPoint: CGPoint(x: 0, y: -layout.descent)
            )
        }

        /// Fill the glyph interior using arbitrary drawing, without leaking
        /// the clip into subsequent operations.
        func clipped(_ body: (inout GraphicsContext) -> Void) {
            context.drawLayer { layer in
                layer.clip(to: glyphs)
                body(&layer)
            }
        }

        /// Edge highlight along the top (`up: false`) or bottom (`up: true`)
        /// inner edges: a stroke shifted vertically and clipped to the glyphs.
        func innerEdge(_ shading: Color, shiftUp: Bool, width: CGFloat, in layer: inout GraphicsContext) {
            let shift = size * 0.018 * (shiftUp ? 1 : -1)
            let shifted = Path(layout.path).applying(CGAffineTransform(translationX: 0, y: shift))
            layer.stroke(shifted, with: .color(shading), lineWidth: width)
        }

        /// Deterministic pseudo-random in [-1, 1] (no Math.random at 120 Hz).
        func jitter(_ seed: Double) -> CGFloat {
            let v = sin(seed * 12.9898) * 43758.5453
            return CGFloat((v - v.rounded(.down)) * 2 - 1)
        }

        switch style {
        case .solid:
            context.fill(glyphs, with: .color(color))

        case .outline:
            context.stroke(
                glyphs,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round)
            )

        case .dashedOutline:
            context.stroke(
                glyphs,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [lineWidth * 2.6, lineWidth * 2.2]
                )
            )

        case .striped:
            clipped { layer in
                let thickness = size * 0.05
                let gap = thickness * 0.9
                var stripes = Path()
                var y = -layout.descent
                while y < layout.ascent {
                    stripes.addRect(CGRect(x: cover.minX, y: y, width: cover.width, height: thickness))
                    y += thickness + gap
                }
                layer.fill(stripes, with: .color(color))
            }

        case .inline:
            // A thin line following the letter shape just inside the edge:
            // a centered stroke clipped to the glyphs shows only its inner half.
            context.fill(glyphs, with: .color(color))
            clipped { layer in
                let contrast: Color = color.isDark ? .white : .black
                let inset = Path(layout.path)
                layer.stroke(inset, with: .color(contrast.opacity(0.85)), lineWidth: lineWidth * 2.4)
            }

        case .neon:
            // Hollow tube with layered blurred halos. Best on a dark background.
            let tube = max(1.5, size * 0.03)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: size * 0.1))
                layer.stroke(glyphs, with: .color(color.opacity(0.7)), lineWidth: tube * 3.6)
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: size * 0.035))
                layer.stroke(glyphs, with: .color(color.opacity(0.9)), lineWidth: tube * 2)
            }
            context.stroke(glyphs, with: .color(color), lineWidth: tube)
            context.stroke(glyphs, with: .color(color.lighter(0.8)), lineWidth: tube * 0.45)

        case .chrome:
            // Metallic ramp derived from the chosen color + moving specular sweep.
            clipped { layer in
                layer.fill(Path(cover), with: vertical([
                    .init(color: color.lighter(0.75), location: 0),
                    .init(color: color.lighter(0.25), location: 0.42),
                    .init(color: color.darker(0.65), location: 0.5),
                    .init(color: color.darker(0.15), location: 0.72),
                    .init(color: color.lighter(0.6), location: 1),
                ]))
                let band = size * 0.5
                let travel = bounds.width + band * 2
                let phase = (time / 2.6).truncatingRemainder(dividingBy: 1)
                let x0 = bounds.minX - band + travel * phase
                layer.fill(Path(cover), with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.5), location: 0.5),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: CGPoint(x: x0, y: 0),
                    endPoint: CGPoint(x: x0 + band, y: 0)
                ))
            }
            context.stroke(glyphs, with: .color(color.darker(0.8)), lineWidth: lineWidth * 0.6)

        case .gold:
            // Fixed gold-leaf palette with a bevel; ignores the text color.
            let paleGold = Color(red: 1, green: 0.95, blue: 0.72)
            let brightGold = Color(red: 1, green: 0.84, blue: 0.29)
            let darkAmber = Color(red: 0.54, green: 0.35, blue: 0.03)
            let midGold = Color(red: 0.9, green: 0.73, blue: 0.23)
            clipped { layer in
                layer.fill(Path(cover), with: vertical([
                    .init(color: paleGold, location: 0),
                    .init(color: brightGold, location: 0.45),
                    .init(color: darkAmber, location: 0.52),
                    .init(color: midGold, location: 0.8),
                    .init(color: paleGold, location: 1),
                ]))
                innerEdge(.white.opacity(0.65), shiftUp: false, width: lineWidth * 1.6, in: &layer)
                innerEdge(darkAmber.opacity(0.8), shiftUp: true, width: lineWidth * 1.6, in: &layer)
            }
            context.stroke(glyphs, with: .color(darkAmber.darker(0.4)), lineWidth: lineWidth * 0.8)

        case .extrude:
            // Solid extrusion trailing down-right, front face on top.
            let depth = size * 0.06
            let steps = 12
            let side = color.darker(0.55)
            for i in stride(from: steps, through: 1, by: -1) {
                let offset = depth * CGFloat(i) / CGFloat(steps)
                let copy = Path(layout.path).applying(
                    CGAffineTransform(translationX: offset, y: -offset)
                )
                context.fill(copy, with: .color(side))
            }
            context.fill(glyphs, with: .color(color))
            context.stroke(glyphs, with: .color(color.darker(0.35)), lineWidth: max(1, lineWidth * 0.4))

        case .popArt:
            // Cyan/magenta ghost copies behind a clean foreground fill.
            let offset = size * 0.035
            let cyan = Color(red: 0, green: 0.9, blue: 1)
            let magenta = Color(red: 1, green: 0.2, blue: 0.75)
            context.fill(
                Path(layout.path).applying(CGAffineTransform(translationX: -offset, y: offset)),
                with: .color(cyan)
            )
            context.fill(
                Path(layout.path).applying(CGAffineTransform(translationX: offset, y: -offset)),
                with: .color(magenta)
            )
            context.fill(glyphs, with: .color(color))

        case .gloss:
            // Candy: vertical shading + white highlight across the upper half.
            clipped { layer in
                layer.fill(Path(cover), with: vertical([
                    .init(color: color.lighter(0.35), location: 0),
                    .init(color: color, location: 0.55),
                    .init(color: color.darker(0.35), location: 1),
                ]))
                let highlightBottom = layout.ascent * 0.42
                layer.fill(
                    Path(CGRect(
                        x: cover.minX, y: highlightBottom,
                        width: cover.width, height: layout.ascent - highlightBottom + size
                    )),
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.65), .white.opacity(0.05)]),
                        startPoint: CGPoint(x: 0, y: layout.ascent),
                        endPoint: CGPoint(x: 0, y: highlightBottom)
                    )
                )
            }
            context.stroke(glyphs, with: .color(color.darker(0.5)), lineWidth: lineWidth * 0.5)

        case .glass:
            // Frosted translucent fill, glossy upper half, bright rim light.
            context.fill(glyphs, with: .color(color.opacity(0.32)))
            clipped { layer in
                layer.fill(
                    Path(CGRect(
                        x: cover.minX, y: layout.ascent * 0.45,
                        width: cover.width, height: layout.ascent
                    )),
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.35), .white.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: layout.ascent),
                        endPoint: CGPoint(x: 0, y: layout.ascent * 0.45)
                    )
                )
            }
            context.stroke(glyphs, with: .color(.white.opacity(0.75)), lineWidth: max(1, lineWidth * 0.5))

        case .stencil:
            // Solid fill with horizontal bridge gaps knocked out to
            // transparency, so the background shows through.
            context.drawLayer { layer in
                layer.fill(glyphs, with: .color(color))
                layer.blendMode = .destinationOut
                let gap = size * 0.05
                var bridges = Path()
                bridges.addRect(CGRect(x: cover.minX, y: layout.ascent * 0.28, width: cover.width, height: gap))
                bridges.addRect(CGRect(x: cover.minX, y: layout.ascent * 0.62, width: cover.width, height: gap))
                layer.fill(bridges, with: .color(.black))
            }

        case .engraved:
            // Debossed: dark top inner edge, light bottom inner edge.
            context.fill(glyphs, with: .color(color.darker(0.15)))
            clipped { layer in
                innerEdge(.black.opacity(0.55), shiftUp: false, width: lineWidth * 2, in: &layer)
                innerEdge(.white.opacity(0.5), shiftUp: true, width: lineWidth * 2, in: &layer)
            }

        case .rainbow:
            // Hue-cycling gradient flowing across the text.
            clipped { layer in
                let phase = (time * 0.12).truncatingRemainder(dividingBy: 1)
                let stops = (0...6).map { i in
                    Gradient.Stop(
                        color: Color(
                            hue: (Double(i) / 6 + phase).truncatingRemainder(dividingBy: 1),
                            saturation: 0.9,
                            brightness: 1
                        ),
                        location: Double(i) / 6
                    )
                }
                layer.fill(Path(cover), with: .linearGradient(
                    Gradient(stops: stops),
                    startPoint: CGPoint(x: bounds.minX, y: 0),
                    endPoint: CGPoint(x: bounds.maxX, y: 0)
                ))
            }

        case .fire:
            // Hot yellow core at the bottom fading to deep red at the top,
            // with a flickering layered glow (no blur filter — 120 Hz safe).
            let deepRed = Color(red: 0.75, green: 0.08, blue: 0)
            let orange = Color(red: 1, green: 0.45, blue: 0)
            let yellow = Color(red: 1, green: 0.85, blue: 0.2)
            let hot = Color(red: 1, green: 0.98, blue: 0.75)
            let flicker = 0.5 + 0.5 * sin(time * 7) * sin(time * 3.1)
            for (widthFactor, opacity) in [(5.0, 0.10), (3.0, 0.14), (1.8, 0.2)] {
                context.stroke(
                    glyphs,
                    with: .color(orange.opacity(opacity * (0.7 + 0.3 * flicker))),
                    lineWidth: lineWidth * widthFactor
                )
            }
            clipped { layer in
                let wobble = 0.03 * sin(time * 5.3)
                layer.fill(Path(cover), with: vertical([
                    .init(color: deepRed, location: 0),
                    .init(color: orange, location: 0.45 + wobble),
                    .init(color: yellow, location: 0.8 + wobble),
                    .init(color: hot, location: 1),
                ]))
            }

        case .glitch:
            // RGB channel split with jittering offsets and a sliced band.
            let amplitude = size * 0.025
            let step = (time * 9).rounded(.down)
            let channels: [(Color, Double)] = [(.red, 1), (.green, 2), (.blue, 3)]
            for (channel, seed) in channels {
                context.drawLayer { layer in
                    layer.blendMode = .screen
                    layer.translateBy(x: jitter(step * 7 + seed) * amplitude, y: 0)
                    layer.fill(glyphs, with: .color(channel))
                }
            }
            context.fill(glyphs, with: .color(color))
            // Horizontal slice shifted sideways.
            let bandHeight = size * 0.1
            let bandY = -layout.descent
                + (layout.ascent + layout.descent - bandHeight) * (jitter(step * 7 + 4) + 1) / 2
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: cover.minX, y: bandY, width: cover.width, height: bandHeight)))
                layer.translateBy(x: jitter(step * 7 + 5) * amplitude * 3, y: 0)
                layer.fill(glyphs, with: .color(color))
            }

        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 14) {
            ForEach(MarqueeStyle.allCases) { style in
                StyledText(
                    text: "Hello!",
                    font: .system,
                    style: style,
                    italic: false,
                    size: 56,
                    color: .orange
                )
            }
        }
        .padding()
    }
    .background(.black)
}
