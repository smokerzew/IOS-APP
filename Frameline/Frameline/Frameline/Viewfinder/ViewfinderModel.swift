import Combine
import PhotosUI
import SwiftUI
import UIKit

/// A short message shown under the top bar.
struct Notice: Identifiable, Equatable {
    enum Tone {
        case info
        case success
        case warning
    }

    let id = UUID()
    let text: String
    let symbol: String
    let tone: Tone
}

/// Where the focus reticle is drawn, in screen coordinates.
struct FocusMark: Identifiable, Equatable {
    let id = UUID()
    let location: CGPoint
}

/// State and behaviour of the viewfinder. Views read this and call its
/// methods; it owns no layout.
@MainActor
final class ViewfinderModel: ObservableObject {
    // Persisted settings.
    @Published private(set) var mode: CaptureMode
    @Published private(set) var aspect: FrameAspect
    @Published private(set) var flash: FlashSetting
    @Published private(set) var timer: TimerSetting
    @Published private(set) var look: Look
    @Published private(set) var lookIntensity: Double
    @Published private(set) var showsGrid: Bool
    @Published private(set) var showsLevel: Bool

    // Session state.
    @Published private(set) var cameraExposure: Double = 0
    @Published private(set) var mediaExposure: Double = 0
    @Published var isPanelOpen = false
    @Published private(set) var activeControl: ControlKind?
    @Published private(set) var countdown: Int?
    @Published private(set) var isImmersive = false
    @Published private(set) var notice: Notice?
    @Published private(set) var focusMark: FocusMark?
    @Published private(set) var blinkCount = 0
    @Published private(set) var viewerZoom: CGFloat = 1
    @Published private(set) var viewerZoomRequest: ZoomRequest?
    @Published private(set) var isExporting = false
    @Published var isPickerPresented = false

    let camera: CameraService
    let media: MediaStore
    let level: LevelMonitor
    let orientation: OrientationMonitor
    let haptics: HapticManager

    private let preferences: Preferences
    private var isAdjusting = false
    private var isSceneActive = false
    private var viewerVisibleRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var pinchStartZoom: CGFloat = 1
    private var zoomRequestCount = 0
    private var countdownTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var focusTask: Task<Void, Never>?

    init(
        preferences: Preferences,
        camera: CameraService,
        media: MediaStore,
        level: LevelMonitor,
        orientation: OrientationMonitor,
        haptics: HapticManager
    ) {
        self.preferences = preferences
        self.camera = camera
        self.media = media
        self.level = level
        self.orientation = orientation
        self.haptics = haptics

        mode = preferences.mode
        aspect = preferences.aspect
        flash = preferences.flash
        timer = preferences.timer
        look = Look.named(preferences.lookID)
        lookIntensity = preferences.lookIntensity
        showsGrid = preferences.showsGrid
        showsLevel = preferences.showsLevel

        camera.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        level.onLevelLocked = { [weak self] in
            self?.haptics.play(.levelLocked)
        }
        pushAppearance()
    }

    // MARK: - Derived state

    /// Video is always recorded 16:9, so the frame follows it in video mode.
    var effectiveAspect: FrameAspect {
        mode == .video ? .sixteenNine : aspect
    }

    /// Width divided by height of the live camera feed in the current mode.
    var feedAspect: CGFloat {
        mode == .video ? 9.0 / 16.0 : 3.0 / 4.0
    }

    var exposure: Double {
        mode.usesCamera ? cameraExposure : mediaExposure
    }

    var exposureRange: ClosedRange<Double> {
        mode.usesCamera ? camera.exposureRange : Metrics.Exposure.range
    }

    /// Flash is offered only when a camera with a flash is active.
    var isFlashUsable: Bool {
        switch mode {
        case .photo: return camera.hasFlash
        case .video: return camera.hasTorch
        case .library: return false
        }
    }

    /// Controls that do something real in the current mode.
    var availableControls: [ControlKind] {
        switch mode {
        case .photo:
            return [.flash, .aspect, .timer, .exposure, .grid, .level]
        case .video:
            return [.flash, .timer, .exposure, .grid, .level]
        case .library:
            return media.media == nil ? [.aspect, .grid] : [.aspect, .exposure, .look, .grid]
        }
    }

    func frameRect(in layout: ViewfinderLayout) -> CGRect {
        isImmersive ? layout.fullRect : layout.frameRect(for: effectiveAspect)
    }

    // MARK: - Mode

    func select(_ newMode: CaptureMode) {
        guard newMode != mode else { return }
        cancelCountdown(announce: false)
        if camera.isRecording { camera.stopRecording() }
        if mode == .library { media.video.pause() }

        mode = newMode
        preferences.mode = newMode
        isImmersive = false
        // The camera starts each mode at neutral exposure.
        cameraExposure = 0
        focusMark = nil
        if let active = activeControl, !availableControls.contains(active) {
            activeControl = nil
        }
        haptics.play(.modeChange)
        AccessibilityAnnouncer.announce("\(newMode.title) mode")
        syncHardware()
    }

    /// Moves along the mode dial. Positive steps go towards the trailing edge.
    func stepMode(by steps: Int) {
        let modes = CaptureMode.allCases
        guard let index = modes.firstIndex(of: mode) else { return }
        let target = min(max(index + steps, 0), modes.count - 1)
        select(modes[target])
    }

    // MARK: - Settings

    func setAspect(_ value: FrameAspect) {
        guard value != aspect else { return }
        aspect = value
        preferences.aspect = value
        haptics.play(.selection)
    }

    func setFlash(_ value: FlashSetting) {
        guard value != flash else { return }
        flash = value
        preferences.flash = value
        haptics.play(.selection)
        AccessibilityAnnouncer.announce("Flash \(value.label)")
    }

    func cycleFlash() {
        setFlash(flash.next)
    }

    func setTimer(_ value: TimerSetting) {
        guard value != timer else { return }
        timer = value
        preferences.timer = value
        haptics.play(.selection)
    }

    func setLook(_ value: Look) {
        guard value != look else { return }
        look = value
        preferences.lookID = value.id
        haptics.play(.selection)
        pushAppearance()
    }

    func setLookIntensity(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard clamped != lookIntensity else { return }
        lookIntensity = clamped
        pushAppearance()
    }

    /// In camera modes this is real exposure compensation on the device. For
    /// imported media it is a brightness adjustment to the picture on screen.
    func setExposure(_ value: Double) {
        let range = exposureRange
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        if mode.usesCamera {
            guard clamped != cameraExposure else { return }
            cameraExposure = clamped
            camera.setExposureBias(clamped)
        } else {
            guard clamped != mediaExposure else { return }
            mediaExposure = clamped
            pushAppearance()
        }
    }

    func toggleGrid() {
        showsGrid.toggle()
        preferences.showsGrid = showsGrid
        haptics.play(.selection)
    }

    func toggleLevel() {
        showsLevel.toggle()
        preferences.showsLevel = showsLevel
        haptics.play(.selection)
        syncLevel()
    }

    /// Brackets a slider drag so stills render as drafts until it ends.
    func setAdjusting(_ adjusting: Bool) {
        guard adjusting != isAdjusting else { return }
        isAdjusting = adjusting
        if !adjusting {
            preferences.lookIntensity = lookIntensity
        }
        pushAppearance()
    }

    func detent() {
        haptics.play(.detent)
    }

    private func pushAppearance() {
        let appearance = Appearance(look: look, intensity: lookIntensity, exposure: mediaExposure)
        media.setAppearance(appearance, interactive: isAdjusting)
    }

    // MARK: - Panel

    func togglePanel() {
        isPanelOpen.toggle()
        if !isPanelOpen { activeControl = nil }
        haptics.play(.selection)
    }

    func closePanel() {
        guard isPanelOpen else { return }
        isPanelOpen = false
        activeControl = nil
    }

    func activate(_ control: ControlKind) {
        switch control {
        case .grid:
            toggleGrid()
        case .level:
            toggleLevel()
        default:
            activeControl = activeControl == control ? nil : control
            haptics.play(.selection)
        }
    }

    // MARK: - Shutter

    func shutterPressed() {
        haptics.play(.shutterDown)
    }

    func shutterReleased() {
        if countdown != nil {
            cancelCountdown(announce: true)
            return
        }
        switch mode {
        case .photo:
            guard camera.status == .running else { return }
            runAfterTimer { [weak self] in self?.capturePhoto() }
        case .video:
            if camera.isRecording {
                camera.stopRecording()
                haptics.play(.shutterRelease)
            } else {
                guard camera.status == .running else { return }
                runAfterTimer { [weak self] in self?.startRecording() }
            }
        case .library:
            guard let item = media.media else {
                isPickerPresented = true
                return
            }
            switch item.kind {
            case .photo:
                saveFramedCopy()
            case .video:
                media.video.togglePlayback()
                haptics.play(.shutterRelease)
            }
        }
    }

    private func capturePhoto() {
        haptics.play(.shutterRelease)
        blinkCount += 1
        camera.capturePhoto(
            flash: isFlashUsable ? flash : .off,
            aspect: effectiveAspect,
            rotationAngle: orientation.captureRotationAngle
        )
    }

    private func startRecording() {
        haptics.play(.shutterRelease)
        camera.startRecording(
            flash: isFlashUsable ? flash : .off,
            rotationAngle: orientation.captureRotationAngle
        )
    }

    private func saveFramedCopy() {
        guard !isExporting else { return }
        isExporting = true
        haptics.play(.shutterRelease)
        blinkCount += 1
        let rect = viewerVisibleRect
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.media.exportFramedCopy(visibleRect: rect)
            self.isExporting = false
            switch outcome {
            case .saved:
                self.present("Framed copy saved to Photos", symbol: "checkmark.circle.fill", tone: .success)
                self.haptics.play(.success)
            case .denied:
                self.presentSaveDenied()
            case .failed:
                self.present("The copy could not be saved", symbol: "exclamationmark.triangle.fill", tone: .warning)
                self.haptics.play(.error)
            }
        }
    }

    // MARK: - Timer

    private func runAfterTimer(_ action: @escaping @MainActor () -> Void) {
        guard timer != .off else {
            action()
            return
        }
        countdownTask?.cancel()
        let total = timer.rawValue
        countdownTask = Task { [weak self] in
            var remaining = total
            while remaining > 0 {
                guard let self, !Task.isCancelled else { return }
                self.countdown = remaining
                self.haptics.play(remaining <= 3 ? .countdownFinal : .countdownTick)
                AccessibilityAnnouncer.announce("\(remaining)")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            guard let self, !Task.isCancelled else { return }
            self.countdown = nil
            action()
        }
    }

    func cancelCountdown(announce: Bool) {
        guard countdown != nil else { return }
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
        if announce {
            haptics.play(.warning)
            present("Timer cancelled", symbol: "timer", tone: .info)
        }
    }

    // MARK: - Camera interaction

    func switchCamera() {
        guard mode.usesCamera, !camera.isRecording, countdown == nil else { return }
        haptics.play(.modeChange)
        camera.switchCamera()
        cameraExposure = 0
        preferences.facing = camera.facing == .back ? .front : .back
    }

    func focus(devicePoint: CGPoint, screenPoint: CGPoint) {
        if isPanelOpen {
            closePanel()
            return
        }
        camera.focus(at: devicePoint)
        haptics.play(.selection)
        focusMark = FocusMark(location: screenPoint)
        focusTask?.cancel()
        focusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Motion.Duration.focus * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.focusMark = nil
        }
    }

    func cameraPinch(scale: CGFloat, began: Bool) {
        if began { pinchStartZoom = camera.displayZoom }
        setCameraZoom(pinchStartZoom * scale, ramp: false)
    }

    func setCameraZoom(_ value: CGFloat, ramp: Bool) {
        let range = camera.zoomRange
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let previous = camera.displayZoom
        // A tick as the zoom passes each lens position.
        if camera.zoomStops.contains(where: { crossed($0.displayFactor, from: previous, to: clamped) }) {
            haptics.play(.detent)
        }
        camera.setZoom(display: clamped, ramp: ramp)
    }

    // MARK: - Viewer interaction

    func viewerDidZoom(_ relative: CGFloat) {
        let previous = viewerZoom
        viewerZoom = relative
        if Metrics.Zoom.viewerStops.contains(where: { crossed($0, from: previous, to: relative) }) {
            haptics.play(.detent)
        }
    }

    func viewerDidMove(visibleRect: CGRect) {
        viewerVisibleRect = visibleRect
    }

    /// Asks the photo viewer to move to a zoom level; 1 fills the frame.
    func setViewerZoom(_ factor: CGFloat, animated: Bool) {
        zoomRequestCount += 1
        viewerZoomRequest = ZoomRequest(id: zoomRequestCount, factor: factor, animated: animated)
        if animated { haptics.play(.selection) }
    }

    func stageTapped() {
        if isPanelOpen {
            closePanel()
        } else if isImmersive {
            setImmersive(false)
        }
    }

    func setImmersive(_ value: Bool) {
        guard value != isImmersive else { return }
        if value { closePanel() }
        isImmersive = value
        haptics.play(.selection)
    }

    private func crossed(_ stop: CGFloat, from previous: CGFloat, to current: CGFloat) -> Bool {
        (previous < stop && current >= stop) || (previous > stop && current <= stop)
    }

    // MARK: - Import

    func presentPicker() {
        closePanel()
        isPickerPresented = true
    }

    func importPicked(_ item: PhotosPickerItem) {
        importTask?.cancel()
        importTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.media.importItem(item)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .imported(let kind):
                self.finishImport(kind)
            case .cancelled:
                break
            case .failed(let message):
                self.present(message, symbol: "exclamationmark.triangle.fill", tone: .warning)
                self.haptics.play(.error)
            }
        }
    }

    private func finishImport(_ kind: ImportedMedia.Kind) {
        mediaExposure = 0
        viewerZoom = 1
        viewerVisibleRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        pushAppearance()
        if mode != .library {
            select(.library)
        } else if let active = activeControl, !availableControls.contains(active) {
            activeControl = nil
        }
        haptics.play(.success)
        AccessibilityAnnouncer.announce(kind == .photo ? "Photo imported" : "Video imported")
    }

    func removeMedia() {
        importTask?.cancel()
        media.clear()
        mediaExposure = 0
        viewerZoom = 1
        isImmersive = false
        activeControl = nil
        pushAppearance()
        haptics.play(.selection)
    }

    // MARK: - Scene lifecycle

    func sceneBecameActive() {
        guard !isSceneActive else { return }
        isSceneActive = true
        haptics.prepare()
        orientation.start()
        syncHardware()
        Task { [weak self] in
            await self?.media.restoreLastMedia()
            self?.pushAppearance()
        }
    }

    /// Covers Control Centre, incoming calls and the app switcher: nothing that
    /// needs the user's attention keeps running.
    func sceneWillResignActive() {
        cancelCountdown(announce: false)
        media.video.pause()
        if camera.isRecording { camera.stopRecording() }
    }

    /// Backgrounding and device lock: release the camera and sensors entirely.
    func sceneDidEnterBackground() {
        isSceneActive = false
        cancelCountdown(announce: false)
        media.video.pause()
        camera.stop()
        level.stop()
        orientation.stop()
        haptics.suspend()
        closePanel()
    }

    func memoryWarningReceived() {
        media.reduceMemoryFootprint()
    }

    private func syncHardware() {
        guard isSceneActive else { return }
        if mode.usesCamera {
            camera.start(mode: mode)
        } else {
            camera.stop()
        }
        syncLevel()
    }

    private func syncLevel() {
        if isSceneActive, showsLevel, mode.usesCamera {
            level.start()
        } else {
            level.stop()
        }
    }

    // MARK: - Notices

    private func handle(_ event: CameraEvent) {
        switch event {
        case .photoSaved:
            present("Photo saved", symbol: "checkmark.circle.fill", tone: .success)
        case .videoSaved:
            present("Video saved", symbol: "checkmark.circle.fill", tone: .success)
            haptics.play(.success)
        case .saveDenied:
            presentSaveDenied()
        case .failed(let message):
            present(message, symbol: "exclamationmark.triangle.fill", tone: .warning)
            haptics.play(.error)
        }
    }

    private func presentSaveDenied() {
        present("Allow Frameline to add to Photos in Settings", symbol: "lock.fill", tone: .warning)
        haptics.play(.warning)
    }

    private func present(_ text: String, symbol: String, tone: Notice.Tone) {
        let next = Notice(text: text, symbol: symbol, tone: tone)
        notice = next
        AccessibilityAnnouncer.announce(text)
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Metrics.Notice.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self?.notice == next { self?.notice = nil }
        }
    }
}
