import SwiftUI

/// Shows how far the phone is from level. The middle bar tilts against two
/// fixed bars and all three turn the accent colour when they line up.
struct LevelOverlay: View {
    @EnvironmentObject private var level: LevelMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colour = level.isLevel ? Theme.Palette.accent : Theme.Palette.text
        HStack(spacing: Metrics.Stage.levelGap) {
            bar(width: Metrics.Stage.levelSegment * Metrics.Stage.levelSideRatio, colour: colour.opacity(Metrics.Shade.levelSide))
            bar(width: Metrics.Stage.levelSegment, colour: colour)
                .rotationEffect(.degrees(level.isLevel ? 0 : -level.offsetDegrees))
            bar(width: Metrics.Stage.levelSegment * Metrics.Stage.levelSideRatio, colour: colour.opacity(Metrics.Shade.levelSide))
        }
        .opacity(level.isMeaningful ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: Motion.Duration.level), value: level.offsetDegrees)
        .animation(Motion.fade, value: level.isLevel)
        .animation(Motion.fade, value: level.isMeaningful)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level")
        .accessibilityValue(level.isLevel ? "Level" : "\(Int(level.offsetDegrees.rounded())) degrees off")
    }

    private func bar(width: CGFloat, colour: Color) -> some View {
        Capsule(style: .continuous)
            .fill(colour)
            .frame(width: width, height: Metrics.Stage.levelThickness)
            .shadow(color: .black.opacity(Metrics.Shade.shadow), radius: Metrics.Line.hairline)
    }
}
