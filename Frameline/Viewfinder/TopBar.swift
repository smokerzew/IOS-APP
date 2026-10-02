import SwiftUI

/// Quick controls above the frame: flash (or import), status, and the toggle
/// for the full controls panel.
struct TopBar: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var media: MediaStore
    @EnvironmentObject private var orientation: OrientationMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StatusBadge()
            HStack(spacing: Metrics.Space.small) {
                if model.mode.usesCamera {
                    flashChip
                } else {
                    importChip
                }
                Spacer(minLength: 0)
                panelToggle
            }
        }
        .padding(.horizontal, Metrics.TopBar.sidePadding)
        .animation(Motion.selection(reduceMotion), value: model.flash)
        .animation(Motion.selection(reduceMotion), value: model.mode)
        .animation(Motion.selection(reduceMotion), value: orientation.glyphAngle)
    }

    private var flashChip: some View {
        let usable = model.isFlashUsable
        let isOn = usable && model.flash == .on
        return Button {
            model.cycleFlash()
        } label: {
            HStack(spacing: Metrics.Space.close) {
                Image(systemName: usable ? model.flash.symbol : FlashSetting.off.symbol)
                    .font(.system(size: Metrics.TopBar.iconSize, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .rotationEffect(orientation.glyphAngle)
                Text(usable ? model.flash.label : "No flash")
                    .font(Theme.Typeface.chrome(Metrics.TopBar.labelSize))
            }
            .foregroundStyle(isOn ? Theme.Palette.onAccent : Theme.Palette.text)
            .padding(.horizontal, Metrics.TopBar.chipPadding)
            .frame(minWidth: Metrics.Touch.minimum, minHeight: Metrics.TopBar.chipHeight)
            .chipBackground(isActive: isOn)
            .frame(minHeight: Metrics.Touch.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!usable)
        .opacity(usable ? 1 : Metrics.Touch.disabledOpacity)
        .accessibilityLabel("Flash")
        .accessibilityValue(usable ? model.flash.label : "Not available on this camera")
        .accessibilityHint("Switches between Auto, On and Off")
        .accessibilityIdentifier(AccessibilityID.flash)
    }

    private var importChip: some View {
        Button {
            model.presentPicker()
        } label: {
            HStack(spacing: Metrics.Space.close) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: Metrics.TopBar.iconSize, weight: .semibold))
                Text(media.media == nil ? "Import" : "Replace")
                    .font(Theme.Typeface.chrome(Metrics.TopBar.labelSize))
            }
            .foregroundStyle(Theme.Palette.text)
            .padding(.horizontal, Metrics.TopBar.chipPadding)
            .frame(minWidth: Metrics.Touch.minimum, minHeight: Metrics.TopBar.chipHeight)
            .chipBackground()
            .frame(minHeight: Metrics.Touch.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(media.media == nil ? "Import from library" : "Replace imported media")
    }

    private var panelToggle: some View {
        Button {
            model.togglePanel()
        } label: {
            Image(systemName: model.isPanelOpen ? "chevron.down" : "slider.horizontal.3")
                .font(.system(size: Metrics.TopBar.iconSize, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .rotationEffect(orientation.glyphAngle)
                .foregroundStyle(model.isPanelOpen ? Theme.Palette.onAccent : Theme.Palette.text)
                .frame(width: Metrics.TopBar.chipHeight, height: Metrics.TopBar.chipHeight)
                .chipBackground(isActive: model.isPanelOpen)
                .frame(width: Metrics.Touch.minimum, height: Metrics.Touch.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(model.isPanelOpen ? "Close controls" : "Open controls")
        .accessibilityIdentifier(AccessibilityID.controlsToggle)
    }
}

/// Says plainly what the viewfinder is showing: a live camera, a recording in
/// progress, or imported media.
struct StatusBadge: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore

    private struct Badge {
        let text: String
        var symbol: String?
        var dot: Color?
        var spoken: String?
    }

    var body: some View {
        let badge = current
        HStack(spacing: Metrics.Space.close) {
            if let dot = badge.dot {
                Circle()
                    .fill(dot)
                    .frame(width: Metrics.Badge.dotSize, height: Metrics.Badge.dotSize)
            } else if let symbol = badge.symbol {
                Image(systemName: symbol)
                    .font(.system(size: Metrics.TypeSize.caption, weight: .bold))
            }
            Text(badge.text)
                .font(Theme.Typeface.numeric(Metrics.TypeSize.small, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.Palette.text)
        .padding(.horizontal, Metrics.Badge.padding)
        .frame(height: Metrics.Badge.height)
        .chipBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.spoken ?? badge.text)
        .accessibilityIdentifier(AccessibilityID.status)
    }

    private var current: Badge {
        if let remaining = model.countdown {
            return Badge(text: "Timer \(remaining)", symbol: "timer")
        }
        if model.isExporting {
            return Badge(text: "Saving", symbol: "square.and.arrow.down")
        }
        switch model.mode {
        case .library:
            return libraryContent
        case .photo, .video:
            return cameraContent
        }
    }

    private var libraryContent: Badge {
        if media.phase == .loading {
            return Badge(text: "Importing", symbol: "arrow.down.circle")
        }
        guard let item = media.media else {
            return Badge(text: "No media", symbol: "photo")
        }
        switch item.kind {
        case .photo:
            return Badge(text: "Imported photo", symbol: "photo.fill")
        case .video:
            return Badge(text: "Imported video", symbol: "film")
        }
    }

    private var cameraContent: Badge {
        if camera.isRecording {
            let clock = Self.clock(camera.recordingSeconds)
            return Badge(text: clock, dot: Theme.Palette.recording, spoken: "Recording, \(clock)")
        }
        switch camera.status {
        case .running:
            let text = model.mode == .video && !camera.recordsAudio ? "Live, no mic" : "Live"
            return Badge(text: text, dot: Theme.Palette.accent, spoken: "Live camera")
        case .starting, .requestingAccess:
            return Badge(text: "Starting", symbol: "camera")
        case .interrupted:
            return Badge(text: "Paused", symbol: "pause.fill")
        case .denied:
            return Badge(text: "No access", symbol: "lock.fill")
        case .unavailable:
            return Badge(text: "No camera", symbol: "video.slash.fill")
        case .idle:
            return Badge(text: "Standby", symbol: "camera")
        }
    }

    static func clock(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
