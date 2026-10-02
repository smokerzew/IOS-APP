import SwiftUI

/// Large countdown shown over the frame while the timer runs.
struct CountdownOverlay: View {
    let remaining: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(remaining)")
            .font(.system(size: Metrics.Stage.countdownSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Theme.Palette.text)
            .shadow(color: .black.opacity(Metrics.Shade.veil), radius: Metrics.Stage.countdownShadowRadius, y: Metrics.Space.hair)
            .contentTransition(.numericText(countsDown: true))
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: remaining)
            .accessibilityHidden(true)
    }
}
