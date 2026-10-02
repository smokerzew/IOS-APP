import SwiftUI

/// Marks where the camera was asked to focus and meter.
struct FocusReticle: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.Palette.accent, lineWidth: Metrics.Line.reticle)
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: Metrics.Stage.focusDotSize, height: Metrics.Stage.focusDotSize)
        }
        .frame(width: Metrics.Stage.focusReticleSize, height: Metrics.Stage.focusReticleSize)
        .shadow(color: .black.opacity(Metrics.Shade.shadow), radius: Metrics.Space.hair)
        .accessibilityHidden(true)
    }
}
