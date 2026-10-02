import SwiftUI

/// Exposure in stops. With a live camera this is real exposure compensation;
/// for imported media it brightens or darkens the picture on screen, and the
/// caption says which of the two is happening.
struct ExposureControl: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService

    var body: some View {
        let value = model.exposure
        VStack(spacing: Metrics.Space.close) {
            HStack(spacing: Metrics.Space.medium) {
                Text(Self.format(value))
                    .font(Theme.Typeface.numeric(Metrics.TypeSize.value, weight: .semibold))
                    .foregroundStyle(abs(value) < 0.001 ? Theme.Palette.text : Theme.Palette.accent)
                    .contentTransition(.numericText())
                if abs(value) >= 0.001 {
                    Button {
                        model.setExposure(0)
                        model.detent()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: Metrics.TypeSize.small, weight: .bold))
                            .foregroundStyle(Theme.Palette.text)
                            .frame(width: Metrics.Touch.minimum, height: Metrics.Badge.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Reset exposure")
                }
            }
            .frame(height: Metrics.Badge.height)

            RulerSlider(
                value: value,
                range: model.exposureRange,
                step: Metrics.Exposure.step,
                majorEvery: Metrics.Exposure.majorEvery,
                onChange: { model.setExposure($0) },
                onEditingChanged: { model.setAdjusting($0) },
                onDetent: { model.detent() }
            )

            Text(model.mode.usesCamera ? "Camera exposure compensation" : "Brightness of the imported picture")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textDim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.mode.usesCamera ? "Exposure" : "Brightness")
        .accessibilityValue("\(Self.format(value)) stops")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? Metrics.Exposure.step : -Metrics.Exposure.step
            model.setExposure(model.exposure + delta)
        }
        .accessibilityIdentifier(AccessibilityID.exposure)
    }

    static func format(_ value: Double) -> String {
        if abs(value) < 0.001 { return "0.0" }
        return String(format: "%+.1f", value)
    }
}
