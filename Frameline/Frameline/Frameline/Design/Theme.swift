import SwiftUI

/// Colours and type for Frameline's own visual identity.
enum Theme {
    enum Palette {
        static let accent = Color(red: 0.36, green: 0.89, blue: 0.78)
        static let recording = Color(red: 1.0, green: 0.29, blue: 0.25)
        static let canvas = Color.black
        static let text = Color.white
        static let textDim = Color.white.opacity(0.6)
        static let hairline = Color.white.opacity(0.18)
        static let chip = Color.white.opacity(0.14)
        static let onAccent = Color(red: 0.02, green: 0.12, blue: 0.1)
    }

    enum Typeface {
        /// Fixed-size chrome label; the viewfinder chrome keeps its size so the layout holds.
        static func chrome(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static func numeric(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight, design: .rounded).monospacedDigit()
        }

        /// Dynamic Type aware text used for messages and panel labels.
        static let message = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let caption = Font.system(.caption, design: .rounded).weight(.medium)
        static let title = Font.system(.headline, design: .rounded)
    }
}

/// Translucent capsule used behind top-bar chips and badges.
struct ChipBackground: ViewModifier {
    var isActive = false

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Theme.Palette.accent : Theme.Palette.chip)
            )
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
}

extension View {
    func chipBackground(isActive: Bool = false) -> some View {
        modifier(ChipBackground(isActive: isActive))
    }
}
