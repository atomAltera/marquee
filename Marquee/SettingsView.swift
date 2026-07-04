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

    @State private var showMarquee = false

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
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
                Section("Текст") {
                    TextField("Введите текст", text: $text)
                        .submitLabel(.done)
                    Toggle("Все буквы заглавные", isOn: $uppercased)
                }

                Section("Оформление") {
                    ColorPicker("Цвет текста", selection: textColor, supportsOpacity: false)
                    ColorPicker("Цвет фона", selection: backgroundColor, supportsOpacity: false)
                }

                Section("Скорость") {
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
                        Text("Запустить")
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
            .navigationTitle("Бегущая строка")
        }
        .fullScreenCover(isPresented: $showMarquee) {
            MarqueeView(
                text: uppercased ? trimmedText.uppercased() : trimmedText,
                textColor: textColor.wrappedValue,
                backgroundColor: backgroundColor.wrappedValue,
                speed: speed
            )
        }
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
