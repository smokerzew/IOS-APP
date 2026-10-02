import SwiftUI

/// Brief confirmation or warning under the top bar.
struct NoticeBanner: View {
    let notice: Notice

    var body: some View {
        HStack(spacing: Metrics.Space.small) {
            Image(systemName: notice.symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(notice.text)
                .foregroundStyle(Theme.Palette.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(Theme.Typeface.message)
        .padding(.horizontal, Metrics.Space.wide)
        .padding(.vertical, Metrics.Notice.verticalPadding)
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .padding(.horizontal, Metrics.TopBar.sidePadding)
    }

    private var tint: Color {
        switch notice.tone {
        case .info: return Theme.Palette.text
        case .success: return Theme.Palette.accent
        case .warning: return Theme.Palette.recording
        }
    }
}
