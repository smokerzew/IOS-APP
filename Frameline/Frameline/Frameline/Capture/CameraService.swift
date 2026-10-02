import AVFoundation
import Combine
import UIKit

/// A lens position the zoom control can jump to, expressed the way it is shown
/// to the user (1 is always the main wide camera).
struct ZoomStop: Identifiable, Equatable {
    let displayFactor: CGFloat

    var id: CGFloat { displayFactor }
}

enum CameraEvent {
    case photoSaved
    case videoSaved
    case saveDenied
    case failed(String)
}

/// Owns the capture session. Session work runs on `queue`; published state is
/// always changed on the main thread.
final class CameraService: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingAccess
        case denied
        case unavailable
        case starting
        case running
        case interrupted
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var facing: CameraFacing
    @Published private(set) var zoomStops: [ZoomStop] = [ZoomStop(displayFactor: 1)]
    @Published private(set) var zoomRange: ClosedRange<CGFloat> = 1...1
    @Published private(set) var displayZoom: CGFloat = 1
    @Published private(set) var hasFlash = false
    @Published private(set) var hasTorch = false
    @Published private(set) var exposureRange: ClosedRange<Double> = Metrics.Exposure.range
    @Published private(set) var isRecording = false
    @Published private(set) var recordingSeconds = 0
    @Published private(set) var isReconfiguring = false
    @Published private(set) var recordsAudio = false
    @Published private(set) var lastCapture: UIImage?

    var onEvent: ((CameraEvent) -> Void)?

    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "app.frameline.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let stateLock = NSLock()

    // Touched only on `queue`.
    private var device: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var configuredMode: CaptureMode?
    private var queueFacing: CameraFacing
    private var zoomMultiplier: CGFloat = 1

    // Guarded by `stateLock`.
    private var aspectsByCapture: [Int64: FrameAspect] = [:]

    private var recordingTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(facing: CameraFacing) {
        self.facing = facing
        self.queueFacing = facing
        super.init()
        observeSession()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Lifecycle

    /// Starts the session for a camera mode, asking for permission first if needed.
    func start(mode: CaptureMode) {
        guard mode.usesCamera else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioIfNeeded(for: mode)
        case .notDetermined:
            publish { self.status = .requestingAccess }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.requestAudioIfNeeded(for: mode)
                } else {
                    self.publish { self.status = .denied }
                }
            }
        default:
            publish { self.status = .denied }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
            self.publish {
                if self.status == .running || self.status == .starting || self.status == .interrupted {
                    self.status = .idle
                }
            }
        }
    }

    private func requestAudioIfNeeded(for mode: CaptureMode) {
        if mode == .video, AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                self?.begin(mode: mode)
            }
        } else {
            begin(mode: mode)
        }
    }

    private func begin(mode: CaptureMode) {
        publish {
            if self.status != .running { self.status = .starting }
            self.isReconfiguring = true
        }
        queue.async { [weak self] in
            guard let self else { return }
            let configured = self.configure(mode: mode, facing: self.queueFacing)
            if configured, !self.session.isRunning {
                self.session.startRunning()
            }
            let running = configured && self.session.isRunning
            self.publish {
                self.status = running ? .running : .unavailable
                self.isReconfiguring = false
            }
        }
    }

    // MARK: - Configuration (queue only)

    private func configure(mode: CaptureMode, facing: CameraFacing) -> Bool {
        let position: AVCaptureDevice.Position = facing == .front ? .front : .back
        let needsDevice = videoInput == nil || videoInput?.device.position != position
        if !needsDevice, configuredMode == mode { return true }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if needsDevice {
            if let existing = videoInput {
                session.removeInput(existing)
                videoInput = nil
                device = nil
            }
            guard let camera = Self.bestCamera(at: position),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                configuredMode = nil
                return false
            }
            session.addInput(input)
            videoInput = input
            device = camera
        }

        if mode == .video {
            if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
            if audioInput == nil,
               AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
               let microphone = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: microphone),
               session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            }
            if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
        } else {
            if session.outputs.contains(movieOutput) { session.removeOutput(movieOutput) }
            if let audio = audioInput {
                session.removeInput(audio)
                audioInput = nil
            }
            if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        }

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        configuredMode = mode
        refreshCapabilities()
        return true
    }

    private static func bestCamera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: position)
        for type in types {
            if let match = discovery.devices.first(where: { $0.deviceType == type }) {
                return match
            }
        }
        return discovery.devices.first
    }

    /// Reads what the active camera can really do, so the interface never
    /// offers a lens or a flash this device does not have.
    private func refreshCapabilities() {
        guard let device else { return }

        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }
        let startsUltraWide = device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera
        let multiplier: CGFloat = startsUltraWide ? 1 / max(switchOvers.first ?? 2, 1) : 1
        zoomMultiplier = multiplier

        let minimumFactor = device.minAvailableVideoZoomFactor
        let maximumFactor = min(device.maxAvailableVideoZoomFactor, Metrics.Zoom.maxDisplayZoom / multiplier)

        var factors: [CGFloat] = [minimumFactor] + switchOvers
        if switchOvers.isEmpty, maximumFactor >= 2 { factors.append(2) }
        let stops = factors
            .filter { $0 >= minimumFactor && $0 <= maximumFactor }
            .map { ZoomStop(displayFactor: (($0 * multiplier) * 10).rounded() / 10) }

        let wideFactor = min(max(1 / multiplier, minimumFactor), maximumFactor)
        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = wideFactor
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.setExposureTargetBias(0, completionHandler: nil)
            device.unlockForConfiguration()
        }

        let flash = photoOutput.supportedFlashModes.contains(.on)
        let torch = device.hasTorch
        let lowEV = max(Double(device.minExposureTargetBias), Metrics.Exposure.range.lowerBound)
        let highEV = min(Double(device.maxExposureTargetBias), Metrics.Exposure.range.upperBound)
        let range = minimumFactor * multiplier...max(maximumFactor * multiplier, minimumFactor * multiplier)
        let shown = wideFactor * multiplier
        let audio = audioInput != nil

        publish {
            self.zoomStops = stops.isEmpty ? [ZoomStop(displayFactor: 1)] : stops
            self.zoomRange = range
            self.displayZoom = shown
            self.hasFlash = flash
            self.hasTorch = torch
            self.exposureRange = lowEV...max(highEV, lowEV)
            self.recordsAudio = audio
        }
    }

    // MARK: - Controls

    func switchCamera() {
        publish { self.isReconfiguring = true }
        queue.async { [weak self] in
            guard let self else { return }
            guard let mode = self.configuredMode, !self.movieOutput.isRecording else {
                self.publish { self.isReconfiguring = false }
                return
            }
            let previous = self.queueFacing
            let next: CameraFacing = previous == .back ? .front : .back
            self.queueFacing = next
            if !self.configure(mode: mode, facing: next) {
                self.queueFacing = previous
                _ = self.configure(mode: mode, facing: previous)
            }
            let resolved = self.queueFacing
            self.publish {
                self.facing = resolved
                self.isReconfiguring = false
            }
        }
    }

    /// Sets zoom in display units. `ramp` glides to the value, as a tap on a
    /// lens stop does; pinches set it directly so they track the fingers.
    func setZoom(display: CGFloat, ramp: Bool) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            let upper = min(device.maxAvailableVideoZoomFactor, Metrics.Zoom.maxDisplayZoom / self.zoomMultiplier)
            let factor = min(max(display / self.zoomMultiplier, device.minAvailableVideoZoomFactor), upper)
            guard (try? device.lockForConfiguration()) != nil else { return }
            if ramp {
                device.ramp(toVideoZoomFactor: factor, withRate: Metrics.Zoom.rampRate)
            } else {
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
            let shown = factor * self.zoomMultiplier
            self.publish { self.displayZoom = shown }
        }
    }

    /// Applies real exposure compensation to the camera.
    func setExposureBias(_ ev: Double) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            let bias = min(max(Float(ev), device.minExposureTargetBias), device.maxExposureTargetBias)
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.setExposureTargetBias(bias, completionHandler: nil)
            device.unlockForConfiguration()
        }
    }

    /// Focuses and meters at a point given in capture-device coordinates (0...1).
    func focus(at devicePoint: CGPoint) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: - Capture

    func capturePhoto(flash: FlashSetting, aspect: FrameAspect, rotationAngle: CGFloat) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning, self.session.outputs.contains(self.photoOutput) else {
                self.emit(.failed("The camera is not ready yet."))
                return
            }
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }

            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            let requested = flash.captureMode
            settings.flashMode = self.photoOutput.supportedFlashModes.contains(requested) ? requested : .off
            settings.photoQualityPrioritization = .quality

            self.stateLock.lock()
            self.aspectsByCapture[settings.uniqueID] = aspect
            self.stateLock.unlock()

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startRecording(flash: FlashSetting, rotationAngle: CGFloat) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning,
                  self.session.outputs.contains(self.movieOutput),
                  !self.movieOutput.isRecording else { return }
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            self.setTorch(for: flash)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }

    /// While recording, the flash setting drives the torch: that is the light
    /// the hardware actually provides for video.
    private func setTorch(for flash: FlashSetting?) {
        guard let device, device.hasTorch else { return }
        let mode: AVCaptureDevice.TorchMode
        switch flash {
        case .some(.on): mode = .on
        case .some(.auto): mode = .auto
        default: mode = .off
        }
        guard device.isTorchModeSupported(mode), (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = mode
        device.unlockForConfiguration()
    }

    // MARK: - Session notifications

    private func observeSession() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: SessionNotification.wasInterrupted, object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.status == .running { self.status = .interrupted }
        })
        observers.append(center.addObserver(forName: SessionNotification.interruptionEnded, object: session, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.status == .interrupted { self.status = .running }
        })
        observers.append(center.addObserver(forName: SessionNotification.runtimeError, object: session, queue: .main) { [weak self] _ in
            self?.recoverFromRuntimeError()
        })
    }

    private func recoverFromRuntimeError() {
        queue.async { [weak self] in
            guard let self, self.configuredMode != nil else { return }
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            self.publish { self.status = running ? .running : .unavailable }
        }
    }

    // MARK: - Helpers

    private func publish(_ change: @escaping () -> Void) {
        if Thread.isMainThread {
            change()
        } else {
            DispatchQueue.main.async(execute: change)
        }
    }

    private func emit(_ event: CameraEvent) {
        publish { self.onEvent?(event) }
    }

    private func startRecordingClock() {
        recordingTimer?.invalidate()
        recordingSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingSeconds += 1
        }
    }

    private func stopRecordingClock() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - Photo delegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        stateLock.lock()
        let aspect = aspectsByCapture.removeValue(forKey: photo.resolvedSettings.uniqueID) ?? .fourThree
        stateLock.unlock()

        guard error == nil, let original = photo.fileDataRepresentation() else {
            emit(.failed("The photo could not be captured."))
            return
        }

        // The sensor delivers 4:3. Other aspects are cropped to match the frame
        // the user composed in; capture metadata is carried over unchanged.
        let data = PhotoCropper.crop(original, to: aspect) ?? original
        let thumbnail = ImagePipeline.thumbnail(from: data, maxPixel: Metrics.Media.thumbnailPixel)
        publish {
            if let thumbnail { self.lastCapture = UIImage(cgImage: thumbnail) }
        }

        PhotoLibrarySaver.savePhoto(data) { [weak self] outcome in
            switch outcome {
            case .saved: self?.emit(.photoSaved)
            case .denied: self?.emit(.saveDenied)
            case .failed: self?.emit(.failed("The photo could not be saved."))
            }
        }
    }
}

// MARK: - Movie delegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        publish {
            self.isRecording = true
            self.startRecordingClock()
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        queue.async { [weak self] in self?.setTorch(for: nil) }
        publish {
            self.isRecording = false
            self.stopRecordingClock()
        }

        var succeeded = true
        if let error = error as NSError? {
            succeeded = (error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
        }
        guard succeeded else {
            try? FileManager.default.removeItem(at: outputFileURL)
            emit(.failed("The recording could not be completed."))
            return
        }

        PhotoLibrarySaver.saveVideo(at: outputFileURL) { [weak self] outcome in
            try? FileManager.default.removeItem(at: outputFileURL)
            switch outcome {
            case .saved: self?.emit(.videoSaved)
            case .denied: self?.emit(.saveDenied)
            case .failed: self?.emit(.failed("The video could not be saved."))
            }
        }
    }
}

// MARK: - Supporting types

private enum SessionNotification {
    // AVFoundation posts these under their constant's own name.
    static let wasInterrupted = Notification.Name("AVCaptureSessionWasInterruptedNotification")
    static let interruptionEnded = Notification.Name("AVCaptureSessionInterruptionEndedNotification")
    static let runtimeError = Notification.Name("AVCaptureSessionRuntimeErrorNotification")
}

private extension FlashSetting {
    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}
