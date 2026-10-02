import SwiftUI

/// Scrubber, time, mute and full-screen controls for an imported video.
/// Play and pause live on the main button.
struct VideoTransport: View {
    @EnvironmentObject private var video: VideoController
    @EnvironmentObject private var model: ViewfinderModel

    @State private var isDragging = false

    var body: some View {
        HStack(spacing: Metrics.Space.medium) {
            Text(StatusBadge.clock(Int(video.currentTime)))
                .font(Theme.Typeface.numeric(Metrics.TypeSize.small))
                .foregroundStyle(Theme.Palette.text)

            scrubber

            Text(StatusBadge.clock(Int(video.duration.rounded())))
                .font(Theme.Typeface.numeric(Metrics.TypeSize.small))
                .foregroundStyle(Theme.Palette.textDim)

            iconButton(
                symbol: video.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: video.isMuted ? "Unmute" : "Mute"
            ) {
                video.isMuted.toggle()
            }

            iconButton(
                symbol: model.isImmersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                label: model.isImmersive ? "Exit full screen" : "Full screen"
            ) {
                model.setImmersive(!model.isImmersive)
            }
        }
        .padding(.leading, Metrics.Transport.sidePadding)
        .padding(.trailing, Metrics.Space.tight)
        .frame(height: Metrics.Transport.height)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }

    private var scrubber: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumb = Metrics.Transport.thumbSize
            let progress: CGFloat = video.duration > 0 ? CGFloat(video.currentTime / video.duration) : 0
            let filled: CGFloat = max(width * progress, 0)
            let thumbTravel: CGFloat = max(width - thumb, 0)
            let thumbX: CGFloat = min(max(filled - thumb / 2, 0), thumbTravel)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Palette.hairline)
                    .frame(height: Metrics.Transport.trackHeight)
                Capsule()
                    .fill(Theme.Palette.accent)
                    .frame(width: filled, height: Metrics.Transport.trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumb, height: thumb)
                    .scaleEffect(isDragging ? Metrics.Transport.thumbActiveScale : 1)
                    .offset(x: thumbX)
            }
            .frame(width: width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard width > 0 else { return }
                        if !isDragging {
                            isDragging = true
                            video.beginScrubbing()
                        }
                        let fraction = min(max(value.location.x / width, 0), 1)
                        video.scrub(to: Double(fraction) * video.duration)
                    }
                    .onEnded { _ in
                        isDragging = false
                        video.endScrubbing()
                    }
            )
        }
        .frame(height: Metrics.Touch.minimum)
        .animation(.easeOut(duration: Motion.Duration.scrubThumb), value: isDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(StatusBadge.clock(Int(video.currentTime))) of \(StatusBadge.clock(Int(video.duration.rounded())))")
        .accessibilityAdjustableAction { direction in
            video.skip(by: direction == .increment ? Metrics.Transport.skipInterval : -Metrics.Transport.skipInterval)
        }
        .accessibilityIdentifier(AccessibilityID.scrubber)
    }

    private func iconButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Metrics.TypeSize.body, weight: .semibold))
                .foregroundStyle(Theme.Palette.text)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Metrics.Touch.minimum, height: Metrics.Touch.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}
