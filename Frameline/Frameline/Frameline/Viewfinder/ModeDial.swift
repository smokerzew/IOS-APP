import SwiftUI

/// Mode selector. The row of names follows the finger, resists at either end,
/// and on release settles on the mode a flick of that speed would reach.
struct ModeDial: View {
    @EnvironmentObject private var model: ViewfinderModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGFloat = 0

    private let modes = CaptureMode.allCases
    private let itemWidth = Metrics.Dial.itemWidth

    var body: some View {
        let selectedIndex = modes.firstIndex(of: model.mode) ?? 0
        GeometryReader { proxy in
            // Centres the selected item, then follows the finger.
            let centred: CGFloat = (proxy.size.width - itemWidth) / 2
            let selectedOffset: CGFloat = CGFloat(selectedIndex) * itemWidth
            HStack(spacing: 0) {
                ForEach(modes) { mode in
                    label(for: mode)
                        .frame(width: itemWidth, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(Motion.dial(reduceMotion)) {
                                model.select(mode)
                            }
                        }
                }
            }
            .offset(x: centred - selectedOffset + dragOffset)
        }
        .frame(height: Metrics.Dial.height)
        .contentShape(Rectangle())
        .gesture(drag(from: selectedIndex))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mode")
        .accessibilityValue(model.mode.title)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.stepMode(by: 1)
            case .decrement: model.stepMode(by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier(AccessibilityID.modeDial)
    }

    private func label(for mode: CaptureMode) -> some View {
        let isSelected = mode == model.mode
        return VStack(spacing: Metrics.Dial.markerSpacing) {
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: Metrics.Dial.markerSize, height: Metrics.Dial.markerSize)
                .opacity(isSelected ? 1 : 0)
                .scaleEffect(isSelected ? 1 : Metrics.Dial.markerRestScale)
            Text(mode.title)
                .font(Theme.Typeface.chrome(Metrics.Dial.labelSize, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Theme.Palette.text : Theme.Palette.textDim)
        }
    }

    private func drag(from index: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Dragging right reveals earlier modes, so the limits are how
                // far the row can travel before running out of modes.
                let upper = CGFloat(index) * itemWidth
                let lower = -CGFloat(modes.count - 1 - index) * itemWidth
                dragOffset = SpringPhysics.rubberBand(
                    value.translation.width,
                    lower: lower,
                    upper: upper,
                    dimension: itemWidth,
                    coefficient: Metrics.Dial.rubberBandCoefficient
                )
            }
            .onEnded { value in
                let steps = SpringPhysics.steps(
                    projected: value.predictedEndTranslation.width,
                    itemWidth: itemWidth,
                    threshold: Metrics.Dial.snapThreshold,
                    limit: Metrics.Dial.maxStepsPerSwipe
                )
                let target = min(max(index - steps, 0), modes.count - 1)
                withAnimation(Motion.dial(reduceMotion)) {
                    model.select(modes[target])
                    dragOffset = 0
                }
            }
    }
}
