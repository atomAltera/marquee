//
//  MarqueeView.swift
//  Marquee
//

import SwiftUI

struct MarqueeView: View {
    let text: String
    let textColor: Color
    let backgroundColor: Color
    let speed: Double

    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()

    var body: some View {
        GeometryReader { geo in
            // The text strip lives in a "landscape" coordinate system and is
            // rotated 90°: left-right motion within the strip appears as
            // bottom-to-top motion on screen.
            let stripWidth = geo.size.height
            let stripHeight = geo.size.width
            let fontSize = stripHeight * 0.7
            let textWidth = Self.measureWidth(of: text, fontSize: fontSize)

            ZStack {
                backgroundColor

                strip(
                    stripWidth: stripWidth,
                    stripHeight: stripHeight,
                    fontSize: fontSize,
                    textWidth: textWidth
                )
                .frame(width: stripWidth, height: stripHeight)
                .rotationEffect(.degrees(90))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            startDate = Date()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @ViewBuilder
    private func strip(
        stripWidth: CGFloat,
        stripHeight: CGFloat,
        fontSize: CGFloat,
        textWidth: CGFloat
    ) -> some View {
        if textWidth <= stripWidth {
            label(fontSize: fontSize)
                .position(x: stripWidth / 2, y: stripHeight / 2)
        } else {
            // Carousel: copies of the text follow one another with a small
            // gap; at start, the first copy is already fully visible at the
            // leading edge.
            let gap = fontSize * 0.75
            let period = textWidth + gap
            let copies = Int(ceil(stripWidth / period)) + 2
            let isRTL = text.startsWithRTLCharacter
            TimelineView(.animation) { timeline in
                let distance = (timeline.date.timeIntervalSince(startDate) * speed)
                    .truncatingRemainder(dividingBy: period)
                ZStack {
                    ForEach(0..<copies, id: \.self) { index in
                        // At start, the text is offset from the leading edge by
                        // the gap size so its beginning has time to be read.
                        let leadingX = isRTL
                            ? stripWidth - textWidth - gap + distance - CGFloat(index) * period
                            : gap + CGFloat(index) * period - distance
                        label(fontSize: fontSize)
                            .position(x: leadingX + textWidth / 2, y: stripHeight / 2)
                    }
                }
            }
        }
    }

    private func label(fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .fixedSize()
    }

    private static func measureWidth(of text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

extension String {
    /// Direction based on the first strongly-directional character:
    /// Hebrew, Arabic, and related scripts are RTL.
    var startsWithRTLCharacter: Bool {
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                if CharacterSet.letters.contains(scalar) { return false }
            }
        }
        return false
    }
}

#Preview {
    MarqueeView(
        text: "Hello, world! This is a marquee.",
        textColor: .white,
        backgroundColor: .black,
        speed: 200
    )
}
