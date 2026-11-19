import SwiftUI

/// Dark, warm palette used by the puzzle panel.
enum Ink {
    static let background = Color(red: 0.055, green: 0.055, blue: 0.06)
    static let surface = Color.white.opacity(0.05)
    static let hairline = Color.white.opacity(0.09)
    static let text = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let secondary = Color(red: 0.62, green: 0.60, blue: 0.57)
    static let tertiary = Color(red: 0.42, green: 0.41, blue: 0.39)
    static let accent = Color(red: 0.89, green: 0.60, blue: 0.29)
    static let good = Color(red: 0.49, green: 0.80, blue: 0.52)
    static let bad = Color(red: 0.93, green: 0.42, blue: 0.37)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static let eyebrow = Font.system(size: 11, weight: .semibold)
}

/// Large filled amber circle (primary action).
struct PrimaryCircleStyle: ButtonStyle {
    var size: CGFloat = 50
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(Ink.background)
            .frame(width: size, height: size)
            .background(Circle().fill(Ink.accent))
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(enabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

/// Small outlined circle (secondary action).
struct SecondaryCircleStyle: ButtonStyle {
    var size: CGFloat = 36
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(Ink.text)
            .frame(width: size, height: size)
            .background(Circle().fill(configuration.isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.03)))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .opacity(enabled ? 1 : 0.35)
            .contentShape(Circle())
    }
}

/// Pill chip, outlined in amber when selected.
struct ChipStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(selected ? Ink.text : Ink.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? Ink.accent.opacity(0.14) : (configuration.isPressed ? Color.white.opacity(0.08) : .clear)))
            .overlay(Capsule().strokeBorder(selected ? Ink.accent : Color.white.opacity(0.16), lineWidth: 1))
            .contentShape(Capsule())
    }
}

/// Amber text link (footer actions).
struct LinkStyle: ButtonStyle {
    var color: Color = Ink.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color.opacity(configuration.isPressed ? 0.6 : 1))
            .contentShape(Rectangle())
    }
}

/// Small borderless gray icon button (header).
struct IconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Ink.text : Ink.secondary)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.04)))
            .contentShape(Circle())
    }
}
