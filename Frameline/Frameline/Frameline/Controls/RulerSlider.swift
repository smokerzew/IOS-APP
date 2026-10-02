import SwiftUI

/// A ruler that slides under a fixed needle. Used for exposure and for look
/// intensity; values snap to `step`, with a tick of feedback on each one.
struct RulerSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let majorEvery: Int
    let onChange: (Double) -> Void
    let onEditingChanged: (Bool) -> Void
    let onDetent: () -> Void

    @State private var startValue: Double?

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(height: Metrics.Ruler.height)
        .contentShape(Rectangle())
        .gesture(drag)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard step > 0 else { return }
        let centre = size.width / 2
        let count = Int(((range.upperBound - range.lowerBound) / step).rounded())

        for index in 0...max(count, 0) {
            let tickValue = range.lowerBound + Double(index) * step
            let x = centre + CGFloat((tickValue - value) / step) * Metrics.Ruler.tickSpacing
            if x < -1 || x > size.width + 1 { continue }

            let isMajor = majorEvery > 0 && index % majorEvery == 0
            let height = isMajor ? Metrics.Ruler.majorHeight : Metrics.Ruler.minorHeight
            // Ticks fade towards the edges so the ruler reads as continuing.
            let distance: CGFloat = abs(x - centre) / max(centre, 1)
            let edgeFade: CGFloat = 1 - min(distance, 1) * Metrics.Shade.tickEdgeFade
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: size.height - height))
            tick.addLine(to: CGPoint(x: x, y: size.height))
            let strength: Double = isMajor ? Metrics.Shade.tickMajor : Metrics.Shade.tickMinor
            context.stroke(tick, with: .color(Color.white.opacity(Double(edgeFade) * strength)), lineWidth: Metrics.Line.hairline)
        }

        var needle = Path()
        needle.move(to: CGPoint(x: centre, y: size.height - Metrics.Ruler.needleHeight))
        needle.addLine(to: CGPoint(x: centre, y: size.height))
        context.stroke(needle, with: .color(Theme.Palette.accent), style: StrokeStyle(lineWidth: Metrics.Line.needle, lineCap: .round))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                let origin = startValue ?? value
                if startValue == nil {
                    startValue = origin
                    onEditingChanged(true)
                }
                // The ruler moves with the finger, so dragging left raises the value.
                let raw = origin - Double(gesture.translation.width / Metrics.Ruler.tickSpacing) * step
                let snapped = (raw / step).rounded() * step
                let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                if abs(clamped - value) > step / 2 {
                    onChange(clamped)
                    onDetent()
                }
            }
            .onEnded { _ in
                startValue = nil
                onEditingChanged(false)
            }
    }
}
