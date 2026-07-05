//
//  SettingsView.swift
//  Marquee
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("marqueeText") private var text = ""
    @AppStorage("textColorHex") private var textColorHex = "#FFFFFF"
    @AppStorage("backgroundColorHex") private var backgroundColorHex = "#000000"
    @AppStorage("speed") private var speed = 200.0
    @AppStorage("uppercased") private var uppercased = true
    @AppStorage("italic") private var italic = false
    @AppStorage("fontName") private var fontName = MarqueeFont.system.rawValue
    @AppStorage("textStyle") private var textStyle = MarqueeStyle.solid.rawValue

    @State private var showMarquee = false
    @FocusState private var textFieldFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var font: MarqueeFont {
        MarqueeFont(rawValue: fontName) ?? .system
    }

    private var style: MarqueeStyle {
        MarqueeStyle(rawValue: textStyle) ?? .solid
    }

    private var previewText: String {
        let base = trimmedText.isEmpty ? String(localized: "Preview") : trimmedText
        return uppercased ? base.uppercased() : base
    }

    private var textColor: Binding<Color> {
        Binding(
            get: { Color(hex: textColorHex) },
            set: { textColorHex = $0.hexString }
        )
    }

    private var backgroundColor: Binding<Color> {
        Binding(
            get: { Color(hex: backgroundColorHex) },
            set: { backgroundColorHex = $0.hexString }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    HStack {
                        TextField("Enter text", text: $text)
                            .submitLabel(.done)
                            .focused($textFieldFocused)
                        if !text.isEmpty {
                            Button {
                                text = ""
                                textFieldFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("All caps", isOn: $uppercased)
                }

                Section("Appearance") {
                    PreviewStrip(
                        text: previewText,
                        font: font,
                        style: style,
                        italic: italic,
                        textColor: textColor.wrappedValue,
                        backgroundColor: backgroundColor.wrappedValue
                    )
                    .listRowInsets(EdgeInsets())

                    NavigationLink {
                        FontPickerView(selection: $fontName)
                    } label: {
                        HStack {
                            Text("Font")
                            Spacer()
                            Text(font.displayName)
                                .font(Font(font.uiFont(size: 17)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        StylePickerView(selection: $textStyle)
                    } label: {
                        HStack {
                            Text("Style")
                            Spacer()
                            Text(style.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Italic", isOn: $italic)
                    ColorPicker("Text color", selection: textColor, supportsOpacity: false)
                    ColorPicker("Background color", selection: backgroundColor, supportsOpacity: false)
                }

                Section("Speed") {
                    HStack {
                        Slider(value: $speed, in: 50...600, step: 10)
                        Text("\(Int(speed))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                }

                Section {
                    Button {
                        showMarquee = true
                    } label: {
                        Text("Start")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .disabled(trimmedText.isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Marquee")
        }
        .fullScreenCover(isPresented: $showMarquee) {
            MarqueeView(
                text: uppercased ? trimmedText.uppercased() : trimmedText,
                textColor: textColor.wrappedValue,
                backgroundColor: backgroundColor.wrappedValue,
                speed: speed,
                font: font,
                style: style,
                italic: italic
            )
        }
    }
}

/// Live preview of the marquee text, rendered by the same `StyledText`
/// component as the marquee screen — what you see here is what you get.
private struct PreviewStrip: View {
    let text: String
    let font: MarqueeFont
    let style: MarqueeStyle
    let italic: Bool
    let textColor: Color
    let backgroundColor: Color

    private static let height: CGFloat = 88
    private static let fontSize: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let measured = StyledText.measure(
                text: text, font: font, size: Self.fontSize, italic: italic
            )
            let available = geo.size.width - 24
            let scale = min(1, available / max(measured.width, 1))

            ZStack {
                backgroundColor
                StyledText(
                    text: text,
                    font: font,
                    style: style,
                    italic: italic,
                    size: Self.fontSize,
                    color: textColor
                )
                .scaleEffect(scale)
            }
        }
        .frame(height: Self.height)
    }
}

private struct FontPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(MarqueeFont.allCases) { font in
            Button {
                selection = font.rawValue
                dismiss()
            } label: {
                HStack {
                    Text(font.displayName)
                        .font(Font(font.uiFont(size: 22)))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection == font.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StylePickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(MarqueeStyle.allCases) { style in
            Button {
                selection = style.rawValue
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(style.displayName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        StyledText(
                            text: "Abc",
                            font: .system,
                            style: style,
                            italic: false,
                            size: 34,
                            color: .primary
                        )
                    }
                    Spacer()
                    if selection == style.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            .scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255))
        )
    }
}

#Preview {
    SettingsView()
}
