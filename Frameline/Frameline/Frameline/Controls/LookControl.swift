import SwiftUI
import UIKit

/// Colour looks for imported media, each previewed on the picture itself, with
/// an intensity ruler for the selected one.
struct LookControl: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var media: MediaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Metrics.Space.small) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.Panel.tileSpacing) {
                    ForEach(Look.all) { look in
                        tile(for: look)
                    }
                }
                .padding(.horizontal, Metrics.Panel.innerPadding)
            }

            if !model.look.isOriginal {
                HStack(spacing: Metrics.Space.medium) {
                    Text("\(Int((model.lookIntensity * 100).rounded()))%")
                        .font(Theme.Typeface.numeric(Metrics.TypeSize.label, weight: .semibold))
                        .foregroundStyle(Theme.Palette.text)
                        .frame(width: Metrics.Panel.intensityLabelWidth, alignment: .trailing)
                    RulerSlider(
                        value: model.lookIntensity,
                        range: 0...1,
                        step: 0.05,
                        majorEvery: 5,
                        onChange: { model.setLookIntensity($0) },
                        onEditingChanged: { model.setAdjusting($0) },
                        onDetent: { model.detent() }
                    )
                }
                .padding(.horizontal, Metrics.Panel.innerPadding)
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Look intensity")
                .accessibilityValue("\(Int((model.lookIntensity * 100).rounded())) percent")
                .accessibilityAdjustableAction { direction in
                    model.setLookIntensity(model.lookIntensity + (direction == .increment ? 0.1 : -0.1))
                    model.setAdjusting(false)
                }
            }
        }
        .animation(Motion.selection(reduceMotion), value: model.look)
    }

    private func tile(for look: Look) -> some View {
        let isSelected = look == model.look
        return Button {
            model.setLook(look)
        } label: {
            VStack(spacing: Metrics.Space.snug) {
                preview(for: look)
                    .frame(width: Metrics.Panel.lookTileSize, height: Metrics.Panel.lookTileSize)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Panel.lookTileCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.Panel.lookTileCorner, style: .continuous)
                            .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.hairline, lineWidth: isSelected ? Metrics.Line.selected : Metrics.Line.hairline)
                    )
                Text(look.name)
                    .font(Theme.Typeface.chrome(Metrics.TypeSize.caption, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.textDim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(look.name) look")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func preview(for look: Look) -> some View {
        if let image = media.lookPreviews[look.id] ?? media.thumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Theme.Palette.chip
        }
    }
}
