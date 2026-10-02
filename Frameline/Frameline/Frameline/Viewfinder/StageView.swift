import SwiftUI
import UIKit

/// The picture area. Content is laid out against the whole screen and revealed
/// through a mask shaped like the current frame, so changing aspect ratio
/// animates the frame around a picture whose centre does not move.
struct StageView: View {
    let layout: ViewfinderLayout

    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var blinkOpacity: Double = 0

    var body: some View {
        let frame = model.frameRect(in: layout)
        ZStack {
            Theme.Palette.canvas

            ZStack {
                content(frame)
                Color.black.opacity(blinkOpacity)
                    .allowsHitTesting(false)
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .mask { frameShape(frame) }

            overlays(frame)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .animation(Motion.frame(reduceMotion), value: frame)
        .animation(Motion.fade, value: media.media?.id)
        .animation(Motion.fade, value: model.showsGrid)
        .animation(Motion.fade, value: model.showsLevel)
        .onChange(of: model.blinkCount) { _, _ in blink() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.stage)
    }

    private var frameCornerRadius: CGFloat {
        model.isImmersive ? 0 : Metrics.Stage.frameCornerRadius
    }

    private func frameShape(_ frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ frame: CGRect) -> some View {
        switch model.mode {
        case .photo, .video:
            cameraContent(frame)
        case .library:
            libraryContent(frame)
        }
    }

    @ViewBuilder
    private func cameraContent(_ frame: CGRect) -> some View {
        switch camera.status {
        case .denied:
            StageMessage(
                symbol: "lock.fill",
                title: "Camera access is off",
                detail: "Frameline needs the camera for Photo and Video. You can turn it on in Settings, or keep using imported media.",
                actionTitle: "Open Settings",
                action: { openSettings() }
            )
            .frame(width: max(frame.width - 2 * Metrics.Deck.sidePadding, 0))
            .position(x: frame.midX, y: frame.midY)
        case .unavailable:
            StageMessage(
                symbol: "video.slash.fill",
                title: "No camera available",
                detail: "This device has no camera Frameline can use right now. Imported photos and videos still work.",
                actionTitle: "Import",
                action: { model.presentPicker() }
            )
            .frame(width: max(frame.width - 2 * Metrics.Deck.sidePadding, 0))
            .position(x: frame.midX, y: frame.midY)
        default:
            livePreview(frame)
        }
    }

    private func livePreview(_ frame: CGRect) -> some View {
        let base = StageGeometry.fillSize(contentAspect: model.feedAspect, frame: layout.size)
        let fitted = StageGeometry.fillSize(contentAspect: model.feedAspect, frame: frame.size)
        let scale = base.width > 0 ? fitted.width / base.width : 1
        let isSettling = camera.isReconfiguring || camera.status != .running

        return ZStack {
            CameraPreview(
                session: camera.session,
                onTap: { devicePoint, location in
                    let screenPoint = CGPoint(
                        x: frame.midX + (location.x - base.width / 2) * scale,
                        y: frame.midY + (location.y - base.height / 2) * scale
                    )
                    // The preview extends past the frame; only taps inside it focus.
                    if frame.contains(screenPoint) {
                        model.focus(devicePoint: devicePoint, screenPoint: screenPoint)
                    } else {
                        model.stageTapped()
                    }
                },
                onPinch: { pinchScale, began in
                    model.cameraPinch(scale: pinchScale, began: began)
                },
                onSwipe: { direction in
                    model.stepMode(by: direction)
                }
            )
            .frame(width: base.width, height: base.height)
            .scaleEffect(scale)
            .position(x: layout.size.width / 2, y: layout.size.height / 2)
            .offset(x: frame.midX - layout.size.width / 2, y: frame.midY - layout.size.height / 2)

            // Veils the feed while the session starts or changes camera.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(isSettling ? 1 : 0)
                .allowsHitTesting(false)
                .animation(Motion.fade, value: isSettling)
        }
    }

    @ViewBuilder
    private func libraryContent(_ frame: CGRect) -> some View {
        if let item = media.media {
            switch item.kind {
            case .photo:
                if let photo = media.stagePhoto {
                    ZoomableImageView(
                        photo: photo,
                        viewport: layout.viewportInsets(for: frame),
                        zoomRequest: model.viewerZoomRequest,
                        reduceMotion: reduceMotion,
                        onZoomChange: { model.viewerDidZoom($0) },
                        onVisibleRectChange: { model.viewerDidMove(visibleRect: $0) },
                        onSingleTap: { model.stageTapped() }
                    )
                    .frame(width: layout.size.width, height: layout.size.height)
                    .id(item.id)
                    .transition(.opacity)
                }
            case .video:
                videoSurface(for: item, frame: frame)
                    .id(item.id)
                    .transition(.opacity)
            }
        } else {
            StageMessage(
                symbol: "photo.on.rectangle.angled",
                title: "Nothing imported yet",
                detail: "Choose a photo or video from your library to frame it, restyle it and look closer.",
                actionTitle: "Import",
                action: { model.presentPicker() }
            )
            .frame(width: max(frame.width - 2 * Metrics.Deck.sidePadding, 0))
            .position(x: frame.midX, y: frame.midY)
        }
    }

    private func videoSurface(for item: ImportedMedia, frame: CGRect) -> some View {
        let base = StageGeometry.fillSize(contentAspect: item.aspect, frame: layout.size)
        let fitted = StageGeometry.fillSize(contentAspect: item.aspect, frame: frame.size)
        let scale = base.width > 0 ? fitted.width / base.width : 1

        return VideoSurface(player: media.video.player)
            .frame(width: base.width, height: base.height)
            .scaleEffect(scale)
            .position(x: layout.size.width / 2, y: layout.size.height / 2)
            .offset(x: frame.midX - layout.size.width / 2, y: frame.midY - layout.size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture { model.stageTapped() }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func overlays(_ frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
            .strokeBorder(Theme.Palette.hairline, lineWidth: Metrics.Stage.borderWidth)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .opacity(model.isImmersive ? 0 : 1)
            .allowsHitTesting(false)

        if model.showsGrid {
            GridOverlay()
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        if model.showsLevel, model.mode.usesCamera, camera.status == .running {
            LevelOverlay()
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        if let mark = model.focusMark, model.mode.usesCamera {
            FocusReticle()
                .position(mark.location)
                .id(mark.id)
                .allowsHitTesting(false)
                .transition(.scale(scale: Metrics.Stage.focusEntryScale).combined(with: .opacity))
        }

        if let remaining = model.countdown {
            CountdownOverlay(remaining: remaining)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        if model.mode == .library, media.media?.kind == .video {
            VideoTransport()
                .frame(width: max(frame.width - 2 * Metrics.Transport.sidePadding, 0))
                .position(
                    x: frame.midX,
                    y: layout.clearBottom(of: frame, immersive: model.isImmersive)
                        - Metrics.Transport.bottomGap - Metrics.Transport.height / 2
                )
                .transition(.opacity)
        }
    }

    // MARK: - Actions

    /// A brief dip to black confirms that the shutter fired.
    private func blink() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: Motion.Duration.blink)) {
            blinkOpacity = 1
        }
        withAnimation(.linear(duration: Motion.Duration.blink).delay(Motion.Duration.blink)) {
            blinkOpacity = 0
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Centred explanation with a single action, used for empty and error states.
struct StageMessage: View {
    let symbol: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.large) {
            Image(systemName: symbol)
                .font(.system(size: Metrics.TypeSize.hero, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.Typeface.title)
                .foregroundStyle(Theme.Palette.text)
            Text(detail)
                .font(Theme.Typeface.message)
                .foregroundStyle(Theme.Palette.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(actionTitle)
                    .font(Theme.Typeface.title)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .padding(.horizontal, Metrics.Stage.messageButtonPadding)
                    .frame(minHeight: Metrics.Touch.minimum)
                    .background(Theme.Palette.accent, in: Capsule(style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, Metrics.Space.tight)
        }
    }
}
