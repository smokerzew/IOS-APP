import SwiftUI

/// Auto, On or Off. The choice is sent to the camera when a photo is taken or
/// a recording starts; it has no meaning for imported media and is not offered there.
struct FlashControl: View {
    @EnvironmentObject private var model: ViewfinderModel

    var body: some View {
        VStack(spacing: Metrics.Space.small) {
            OptionStrip(
                options: FlashSetting.allCases,
                selection: model.flash,
                title: { $0.label },
                spokenTitle: { "Flash \($0.label)" },
                onSelect: { model.setFlash($0) }
            )
            .disabled(!model.isFlashUsable)
            .opacity(model.isFlashUsable ? 1 : Metrics.Touch.disabledOpacity)

            Text(caption)
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textDim)
        }
    }

    private var caption: String {
        if !model.isFlashUsable { return "This camera has no flash" }
        return model.mode == .video ? "Lights the scene while recording" : "Fires when the photo is taken"
    }
}
