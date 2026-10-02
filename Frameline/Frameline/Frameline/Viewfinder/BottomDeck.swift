import SwiftUI
import UIKit

/// Everything below the frame: zoom (or the controls panel), the mode dial and
/// the row with the thumbnail, shutter and side button.
struct BottomDeck: View {
    let layout: ViewfinderLayout

    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore
    @EnvironmentObject private var orientation: OrientationMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if model.isPanelOpen {
                    ControlsPanel()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ZoomControl()
                        .frame(height: Metrics.Zoom.rowHeight)
                        .transition(.opacity)
                }
            }
            .frame(minHeight: Metrics.Zoom.rowHeight, alignment: .bottom)

            ModeDial()

            shutterRow
                .frame(height: Metrics.Deck.shutterRowHeight)
        }
        .padding(.bottom, Metrics.Deck.bottomPadding + layout.insets.bottom)
        .background(alignment: .bottom) { scrim }
        .animation(Motion.panel(reduceMotion), value: model.isPanelOpen)
        .animation(Motion.panel(reduceMotion), value: model.activeControl)
        .animation(Motion.selection(reduceMotion), value: orientation.glyphAngle)
    }

    /// Keeps the controls legible where the frame runs underneath them.
    private var scrim: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black.opacity(Metrics.Deck.scrimOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Metrics.Deck.scrimFade)
            Color.black.opacity(Metrics.Deck.scrimOpacity)
                .frame(height: layout.deckHeight)
        }
        .allowsHitTesting(false)
    }

    private var shutterRow: some View {
        HStack(spacing: 0) {
            thumbnailButton
            Spacer(minLength: 0)
            ShutterButton()
            Spacer(minLength: 0)
            sideButton
        }
        .padding(.horizontal, Metrics.Deck.sidePadding)
    }

    // MARK: - Thumbnail

    private var thumbnailImage: UIImage? {
        if model.mode.usesCamera, let capture = camera.lastCapture { return capture }
        return media.thumbnail
    }

    private var thumbnailButton: some View {
        Button {
            model.presentPicker()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.Deck.thumbnailCorner, style: .continuous)
                    .fill(Theme.Palette.chip)
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Metrics.Deck.thumbnailSize, height: Metrics.Deck.thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.Deck.thumbnailCorner, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: Metrics.Deck.thumbnailEntryScale)))
                        .id(ObjectIdentifier(image))
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: Metrics.Deck.sideIconSize, weight: .medium))
                        .foregroundStyle(Theme.Palette.textDim)
                }
                if media.phase == .loading {
                    RoundedRectangle(cornerRadius: Metrics.Deck.thumbnailCorner, style: .continuous)
                        .fill(Color.black.opacity(Metrics.Shade.veil))
                    ProgressView()
                        .tint(Theme.Palette.text)
                }
            }
            .frame(width: Metrics.Deck.thumbnailSize, height: Metrics.Deck.thumbnailSize)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.Deck.thumbnailCorner, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Metrics.Line.hairline)
            )
            .rotationEffect(orientation.glyphAngle)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(Motion.selection(reduceMotion), value: thumbnailImage)
        .contextMenu {
            Button {
                model.presentPicker()
            } label: {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            if media.media != nil {
                Button(role: .destructive) {
                    model.removeMedia()
                } label: {
                    Label("Remove from Frameline", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel("Import from library")
        .accessibilityHint("Opens the system photo picker. Touch and hold for more options.")
        .accessibilityIdentifier(AccessibilityID.thumbnail)
    }

    // MARK: - Side button

    @ViewBuilder
    private var sideButton: some View {
        if model.mode.usesCamera {
            sideCircle(
                symbol: "arrow.triangle.2.circlepath",
                label: camera.facing == .back ? "Switch to front camera" : "Switch to back camera",
                isEnabled: camera.status == .running && !camera.isRecording && !camera.isReconfiguring
            ) {
                model.switchCamera()
            }
        } else if media.media != nil {
            sideCircle(symbol: "arrow.up.left.and.arrow.down.right", label: "Full screen", isEnabled: true) {
                model.setImmersive(true)
            }
        } else {
            sideCircle(symbol: "plus", label: "Import from library", isEnabled: true) {
                model.presentPicker()
            }
        }
    }

    private func sideCircle(
        symbol: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Metrics.Deck.sideIconSize, weight: .semibold))
                .foregroundStyle(Theme.Palette.text)
                .rotationEffect(orientation.glyphAngle)
                .rotationEffect(.degrees(camera.facing == .front && model.mode.usesCamera ? 180 : 0))
                .frame(width: Metrics.Deck.sideButtonSize, height: Metrics.Deck.sideButtonSize)
                .background(Theme.Palette.chip, in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Metrics.Touch.disabledOpacity)
        .animation(Motion.frame(reduceMotion), value: camera.facing)
        .accessibilityLabel(label)
        .accessibilityIdentifier(AccessibilityID.sideButton)
    }
}
