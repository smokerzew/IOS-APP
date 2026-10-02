#if DEBUG
import SwiftUI
import UIKit

/// Draws a reference image over the app for side-by-side measurement.
/// The image fills the screen width by default and can be nudged, scaled and
/// faded from the debug panel.
struct ReferenceOverlay: View {
    let image: UIImage
    let layout: ViewfinderLayout
    @ObservedObject var settings: DebugSettings

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: layout.size.width)
            .scaleEffect(settings.referenceScale)
            .offset(x: settings.referenceOffsetX, y: settings.referenceOffsetY)
            .opacity(settings.referenceOpacity)
            .position(x: layout.size.width / 2, y: layout.size.height / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#endif
