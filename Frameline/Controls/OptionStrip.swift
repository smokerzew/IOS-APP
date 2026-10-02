import SwiftUI

/// A row of mutually exclusive choices with a highlight that slides to the
/// selected one.
struct OptionStrip<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let spokenTitle: (Option) -> String
    let onSelect: (Option) -> Void

    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.Space.tight) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    onSelect(option)
                } label: {
                    Text(title(option))
                        .font(Theme.Typeface.numeric(Metrics.TypeSize.body, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.Panel.optionHeight)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Theme.Palette.accent)
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .frame(minHeight: Metrics.Touch.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spokenTitle(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier(AccessibilityID.option(title(option)))
            }
        }
        .padding(.horizontal, Metrics.Space.tight)
        .background(Theme.Palette.chip, in: Capsule(style: .continuous))
        .animation(Motion.selection(reduceMotion), value: selection)
    }
}
