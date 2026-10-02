import SwiftUI

/// The expandable controls panel. It lists only the controls that do something
/// in the current mode; the selected one opens a detail row above the tiles.
/// Tapping the picture or swiping the panel down closes it.
struct ControlsPanel: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var media: MediaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Metrics.Space.medium) {
            if let active = model.activeControl {
                detail(for: active)
                    .padding(.horizontal, active == .look ? 0 : Metrics.Panel.innerPadding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(active)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.Panel.tileSpacing) {
                    ForEach(model.availableControls) { kind in
                        tile(for: kind)
                    }
                }
                .padding(.horizontal, Metrics.Panel.innerPadding)
            }
        }
        .padding(.vertical, Metrics.Panel.innerPadding)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Metrics.Panel.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.Panel.cornerRadius, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: Metrics.Line.hairline)
        )
        .padding(.horizontal, Metrics.Panel.outerPadding)
        .padding(.bottom, Metrics.Panel.bottomGap)
        .simultaneousGesture(dismissDrag)
        .accessibilityIdentifier(AccessibilityID.controlsPanel)
    }

    @ViewBuilder
    private func detail(for kind: ControlKind) -> some View {
        switch kind {
        case .flash: FlashControl()
        case .aspect: AspectControl()
        case .timer: TimerControl()
        case .exposure: ExposureControl()
        case .look: LookControl()
        case .grid, .level: EmptyView()
        }
    }

    private func tile(for kind: ControlKind) -> some View {
        let isActive = isHighlighted(kind)
        return Button {
            model.activate(kind)
        } label: {
            VStack(spacing: Metrics.Space.snug) {
                Image(systemName: kind.symbol)
                    .font(.system(size: Metrics.TypeSize.glyph, weight: .semibold))
                Text(kind.title)
                    .font(Theme.Typeface.chrome(Metrics.TypeSize.caption))
                Text(value(for: kind))
                    .font(Theme.Typeface.numeric(Metrics.TypeSize.micro, weight: .medium))
                    .opacity(Metrics.Shade.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? Theme.Palette.onAccent : Theme.Palette.text)
            .frame(width: Metrics.Panel.tileWidth, height: Metrics.Panel.tileHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.Panel.tileCorner, style: .continuous)
                    .fill(isActive ? Theme.Palette.accent : Theme.Palette.chip)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(kind.title)
        .accessibilityValue(value(for: kind))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier(AccessibilityID.control(kind))
    }

    private func isHighlighted(_ kind: ControlKind) -> Bool {
        switch kind {
        case .grid: return model.showsGrid
        case .level: return model.showsLevel
        default: return model.activeControl == kind
        }
    }

    private func value(for kind: ControlKind) -> String {
        switch kind {
        case .flash: return model.isFlashUsable ? model.flash.label : "None"
        case .aspect: return model.aspect.label
        case .timer: return model.timer.label
        case .exposure: return ExposureControl.format(model.exposure)
        case .look: return model.look.name
        case .grid: return model.showsGrid ? "On" : "Off"
        case .level: return model.showsLevel ? "On" : "Off"
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let vertical = value.translation.height
                let isMostlyVertical = abs(vertical) > abs(value.translation.width)
                let flung = value.predictedEndTranslation.height > Metrics.Panel.dismissDragDistance * 3
                if isMostlyVertical, vertical > Metrics.Panel.dismissDragDistance || flung {
                    model.closePanel()
                }
            }
    }
}
