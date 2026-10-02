import SwiftUI

/// Shared press response for chips and small buttons.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Metrics.Touch.pressedScale : 1)
            .opacity(configuration.isPressed ? Metrics.Touch.pressedOpacity : 1)
            .animation(Motion.press(reduceMotion), value: configuration.isPressed)
    }
}
