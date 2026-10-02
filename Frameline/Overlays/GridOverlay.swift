import SwiftUI

/// Rule-of-thirds lines. Sized to the frame by its parent, so the grid always
/// matches the current aspect ratio.
struct GridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                for index in 1...2 {
                    let x = width * CGFloat(index) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    let y = height * CGFloat(index) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.white.opacity(Metrics.Shade.grid), lineWidth: Metrics.Stage.gridLineWidth)
        }
        .accessibilityHidden(true)
    }
}
