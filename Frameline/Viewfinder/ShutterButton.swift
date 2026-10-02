import SwiftUI

/// What the main button does right now. Its face always matches its action.
enum ShutterFace: Equatable {
    case capture
    case record
    case stopRecording
    case cancelTimer
    case saveCopy
    case play
    case pause
    case importMedia

    var glyph: String? {
        switch self {
        case .capture, .record, .stopRecording: return nil
        case .cancelTimer: return "xmark"
        case .saveCopy: return "square.and.arrow.down"
        case .play: return "play.fill"
        case .pause: return "pause.fill"
        case .importMedia: return "plus"
        }
    }

    var label: String {
        switch self {
        case .capture: return "Take photo"
        case .record: return "Start recording"
        case .stopRecording: return "Stop recording"
        case .cancelTimer: return "Cancel timer"
        case .saveCopy: return "Save framed copy"
        case .play: return "Play"
        case .pause: return "Pause"
        case .importMedia: return "Import from library"
        }
    }

    var hint: String {
        switch self {
        case .saveCopy: return "Saves what is inside the frame, with the current look, as a new photo"
        case .capture, .record: return "Uses the timer if one is set"
        default: return ""
        }
    }
}

struct ShutterButton: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore
    @EnvironmentObject private var video: VideoController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let face = currentFace
        Button {
            model.shutterReleased()
        } label: {
            ShutterFaceView(face: face)
        }
        .buttonStyle(ShutterPressStyle(reduceMotion: reduceMotion) { model.shutterPressed() })
        .disabled(isDisabled(face))
        .opacity(isDisabled(face) ? Metrics.Touch.disabledOpacity : 1)
        .animation(Motion.selection(reduceMotion), value: face)
        .accessibilityLabel(face.label)
        .accessibilityHint(face.hint)
        .accessibilityIdentifier(AccessibilityID.shutter)
    }

    private var currentFace: ShutterFace {
        if model.countdown != nil { return .cancelTimer }
        switch model.mode {
        case .photo:
            return .capture
        case .video:
            return camera.isRecording ? .stopRecording : .record
        case .library:
            guard let item = media.media else { return .importMedia }
            switch item.kind {
            case .photo: return .saveCopy
            case .video: return video.isPlaying ? .pause : .play
            }
        }
    }

    private func isDisabled(_ face: ShutterFace) -> Bool {
        switch face {
        case .capture, .record:
            return camera.status != .running || camera.isReconfiguring
        case .saveCopy:
            return model.isExporting
        default:
            return false
        }
    }
}

/// A ring of fine ticks around a core that changes shape with its action.
struct ShutterFaceView: View {
    let face: ShutterFace

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: Metrics.Shutter.ringWidth,
                        dash: [Metrics.Shutter.ringDash, Metrics.Shutter.ringGap]
                    )
                )
            RoundedRectangle(cornerRadius: coreCorner, style: .continuous)
                .fill(coreColor)
                .frame(width: coreSize, height: coreSize)
            if let glyph = face.glyph {
                Image(systemName: glyph)
                    .font(.system(size: Metrics.Shutter.glyphSize, weight: .bold))
                    .foregroundStyle(Theme.Palette.onAccent)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Metrics.Shutter.diameter, height: Metrics.Shutter.diameter)
        .contentShape(Circle())
    }

    private var fullCoreSize: CGFloat {
        Metrics.Shutter.diameter - 2 * (Metrics.Shutter.ringWidth + Metrics.Shutter.coreInset)
    }

    private var coreSize: CGFloat {
        face == .stopRecording ? Metrics.Shutter.recordingCoreSize : fullCoreSize
    }

    private var coreCorner: CGFloat {
        face == .stopRecording ? Metrics.Shutter.recordingCorner : fullCoreSize / 2
    }

    private var coreColor: Color {
        switch face {
        case .record, .stopRecording: return Theme.Palette.recording
        case .capture: return Theme.Palette.text
        default: return Theme.Palette.accent
        }
    }

    private var ringColor: Color {
        switch face {
        case .record, .stopRecording: return Theme.Palette.recording.opacity(Metrics.Shade.recordingRing)
        case .capture: return Theme.Palette.text
        default: return Theme.Palette.accent
        }
    }
}

/// Gives the button weight: it sinks on touch and springs back on release.
struct ShutterPressStyle: ButtonStyle {
    let reduceMotion: Bool
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Metrics.Shutter.pressedScale : 1)
            .animation(Motion.press(reduceMotion), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { onPress() }
            }
    }
}
