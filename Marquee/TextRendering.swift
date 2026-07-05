//
//  TextRendering.swift
//  Marquee
//

import SwiftUI
import CoreText

// MARK: - Font choices

/// Curated shortlist of fonts available on every iOS device.
enum MarqueeFont: String, CaseIterable, Identifiable {
    case system
    case rounded
    case helvetica
    case georgia
    case avenir
    case menlo
    case typewriter
    case futura
    case chalkboard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "SF (Default)"
        case .rounded: return "SF Rounded"
        case .helvetica: return "Helvetica Neue"
        case .georgia: return "Georgia"
        case .avenir: return "Avenir Next"
        case .menlo: return "Menlo"
        case .typewriter: return "American Typewriter"
        case .futura: return "Futura"
        case .chalkboard: return "Chalkboard"
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: .bold)
        switch self {
        case .system:
            return fallback
        case .rounded:
            guard let descriptor = fallback.fontDescriptor.withDesign(.rounded) else { return fallback }
            return UIFont(descriptor: descriptor, size: size)
        case .helvetica:
            return UIFont(name: "HelveticaNeue-Bold", size: size) ?? fallback
        case .georgia:
            return UIFont(name: "Georgia-Bold", size: size) ?? fallback
        case .avenir:
            return UIFont(name: "AvenirNext-Bold", size: size) ?? fallback
        case .menlo:
            return UIFont(name: "Menlo-Bold", size: size) ?? fallback
        case .typewriter:
            return UIFont(name: "AmericanTypewriter-Bold", size: size) ?? fallback
        case .futura:
            return UIFont(name: "Futura-Bold", size: size) ?? fallback
        case .chalkboard:
            return UIFont(name: "ChalkboardSE-Bold", size: size) ?? fallback
        }
    }
}

// MARK: - Style choices

enum MarqueeStyle: String, CaseIterable, Identifiable {
    case solid
    case outline
    case dashedOutline
    case striped

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .solid: return "Solid"
        case .outline: return "Outline"
        case .dashedOutline: return "Dashed outline"
        case .striped: return "Striped"
        }
    }
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

    /// Uniform padding around the glyphs so strokes and LED dots are not
    /// clipped at the canvas edge. Constant across styles, so switching
    /// styles never changes the text width or carousel spacing.
    var pad: CGFloat { fontSize * 0.08 }

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
struct StyledText: View {
    let text: String
    let font: MarqueeFont
    let style: MarqueeStyle
    let italic: Bool
    let size: CGFloat
    let color: Color

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

            let glyphs = Path(layout.path)
            let lineWidth = max(1, size * 0.035)

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
                context.clip(to: glyphs)
                let bounds = layout.path.boundingBox
                let thickness = size * 0.05
                let gap = thickness * 0.9
                var stripes = Path()
                var y = -layout.descent
                while y < layout.ascent {
                    stripes.addRect(CGRect(
                        x: bounds.minX - lineWidth,
                        y: y,
                        width: bounds.width + lineWidth * 2,
                        height: thickness
                    ))
                    y += thickness + gap
                }
                context.fill(stripes, with: .color(color))
            }
        }
        .frame(width: layout.frameSize.width, height: layout.frameSize.height)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(MarqueeStyle.allCases) { style in
            StyledText(
                text: "Hello!",
                font: .system,
                style: style,
                italic: false,
                size: 60,
                color: .white
            )
        }
    }
    .padding()
    .background(.black)
}
