import SwiftUI

/// Chooses the shape of the frame. The frame on screen changes with it, and
/// photos taken in Photo mode are saved in the same shape.
struct AspectControl: View {
    @EnvironmentObject private var model: ViewfinderModel

    var body: some View {
        OptionStrip(
            options: FrameAspect.allCases,
            selection: model.aspect,
            title: { $0.label },
            spokenTitle: { "Aspect ratio \($0.spokenLabel)" },
            onSelect: { model.setAspect($0) }
        )
    }
}
