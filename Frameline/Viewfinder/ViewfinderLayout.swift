import SwiftUI
import UIKit

/// Resolves the screen into the rectangles the viewfinder is built from.
/// Everything is derived from the live container size and safe-area insets,
/// so the same rules hold on every iPhone.
struct ViewfinderLayout: Equatable {
    let size: CGSize
    let insets: EdgeInsets

    var fullRect: CGRect { CGRect(origin: .zero, size: size) }

    var topBarRect: CGRect {
        CGRect(x: 0, y: insets.top, width: size.width, height: Metrics.TopBar.height)
    }

    var deckHeight: CGFloat {
        Metrics.Zoom.rowHeight
            + Metrics.Dial.height
            + Metrics.Deck.shutterRowHeight
            + Metrics.Deck.bottomPadding
            + insets.bottom
    }

    var deckRect: CGRect {
        CGRect(x: 0, y: size.height - deckHeight, width: size.width, height: deckHeight)
    }

    /// The 4:3 rectangle directly under the top bar. Every frame shares its
    /// vertical centre, so changing aspect never moves the picture's centre.
    var anchorRect: CGRect {
        let top = topBarRect.maxY
        let height = min(size.width * FrameAspect.fourThree.heightOverWidth, max(size.height - top, 0))
        return CGRect(x: 0, y: top, width: size.width, height: height)
    }

    func frameRect(for aspect: FrameAspect) -> CGRect {
        var width = size.width
        var height = width * aspect.heightOverWidth
        if height > size.height, aspect.heightOverWidth > 0 {
            height = size.height
            width = height / aspect.heightOverWidth
        }
        let half = height / 2
        let midY = min(max(anchorRect.midY, half), max(size.height - half, half))
        return CGRect(x: (size.width - width) / 2, y: midY - half, width: width, height: height)
    }

    /// Insets that describe `frame` inside the full screen.
    func viewportInsets(for frame: CGRect) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(frame.minY, 0),
            left: max(frame.minX, 0),
            bottom: max(size.height - frame.maxY, 0),
            right: max(size.width - frame.maxX, 0)
        )
    }

    /// Bottom edge available to overlays that must stay clear of the deck.
    func clearBottom(of frame: CGRect, immersive: Bool) -> CGFloat {
        if immersive { return size.height - max(insets.bottom, Metrics.Transport.bottomGap) }
        return min(frame.maxY, deckRect.minY)
    }
}

enum StageGeometry {
    /// Size at which content of `contentAspect` (width / height) fills `frame`
    /// without distortion.
    static func fillSize(contentAspect: CGFloat, frame: CGSize) -> CGSize {
        guard contentAspect > 0, frame.width > 0, frame.height > 0 else { return frame }
        let frameAspect = frame.width / frame.height
        if contentAspect > frameAspect {
            return CGSize(width: frame.height * contentAspect, height: frame.height)
        }
        return CGSize(width: frame.width, height: frame.width / contentAspect)
    }
}
