import AVFoundation
import Combine
import CoreImage
import Foundation

/// Thread-safe holder for the appearance used by the video filter, which runs
/// on AVFoundation's own queue.
final class AppearanceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = Appearance.neutral

    var value: Appearance {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}

/// Playback of an imported video through AVPlayer. Frames are streamed and
/// decoded on demand; the file is never loaded into memory.
@MainActor
final class VideoController: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isLoaded = false
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var currentTime: Double = 0
    @Published var isMuted = false {
        didSet { player.isMuted = isMuted }
    }

    private let appearanceBox = AppearanceBox()
    private var filterComposition: AVVideoComposition?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    private var isScrubbing = false
    private var resumeAfterScrub = false
    private var isSeeking = false
    private var queuedSeek: Double?

    private let tickInterval = CMTime(value: 1, timescale: 30)
    private let timescale: CMTimeScale = 600

    init() {
        player.actionAtItemEnd = .pause
    }

    // MARK: - Loading

    func load(_ media: ImportedMedia, appearance: Appearance) {
        unload()

        let asset = AVURLAsset(url: media.url)
        let item = AVPlayerItem(asset: asset)

        appearanceBox.value = appearance
        let box = appearanceBox
        // Built once per item; the filter reads the current appearance for
        // every frame, so changing a look needs no new composition.
        filterComposition = AVMutableVideoComposition(asset: asset) { request in
            let styled = LookRenderer.apply(box.value, to: request.sourceImage)
            request.finish(with: styled.cropped(to: request.sourceImage.extent), context: nil)
        }
        // Unstyled video plays straight through, untouched.
        item.videoComposition = appearance.isNeutral ? nil : filterComposition

        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted
        duration = media.duration
        currentTime = 0
        isLoaded = true
        observe(item)
    }

    func unload() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        player.replaceCurrentItem(with: nil)
        filterComposition = nil
        isLoaded = false
        isPlaying = false
        duration = 0
        currentTime = 0
        isScrubbing = false
        isSeeking = false
        queuedSeek = nil
    }

    private func observe(_ item: AVPlayerItem) {
        timeObserver = player.addPeriodicTimeObserver(forInterval: tickInterval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            MainActor.assumeIsolated {
                self?.handleTick(seconds)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleEnd()
            }
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor [weak self] in
                self?.syncPlaying(playing)
            }
        }
    }

    // MARK: - Transport

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard isLoaded else { return }
        if duration > 0, currentTime >= duration - Metrics.Transport.seekTolerance {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = 0
        }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func skip(by seconds: Double) {
        guard isLoaded else { return }
        let target = min(max(currentTime + seconds, 0), duration)
        currentTime = target
        seek(to: target, precise: true)
    }

    func beginScrubbing() {
        guard isLoaded, !isScrubbing else { return }
        isScrubbing = true
        resumeAfterScrub = isPlaying
        player.pause()
    }

    func scrub(to seconds: Double) {
        guard isScrubbing else { return }
        let target = min(max(seconds, 0), duration)
        currentTime = target
        seek(to: target, precise: false)
    }

    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        seek(to: currentTime, precise: true)
        if resumeAfterScrub { player.play() }
    }

    /// Seeks are chained rather than stacked: while one is in flight only the
    /// newest target is remembered, so scrubbing stays responsive.
    private func seek(to seconds: Double, precise: Bool) {
        if isSeeking {
            queuedSeek = seconds
            return
        }
        isSeeking = true
        let tolerance = precise ? CMTime.zero : CMTime(seconds: Metrics.Transport.seekTolerance, preferredTimescale: timescale)
        let target = CMTime(seconds: seconds, preferredTimescale: timescale)
        player.seek(to: target, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishSeek(precise: precise)
            }
        }
    }

    private func finishSeek(precise: Bool) {
        isSeeking = false
        if let next = queuedSeek {
            queuedSeek = nil
            seek(to: next, precise: precise || !isScrubbing)
        }
    }

    // MARK: - Appearance

    func setAppearance(_ appearance: Appearance) {
        appearanceBox.value = appearance
        guard let item = player.currentItem else { return }
        let wanted: AVVideoComposition? = appearance.isNeutral ? nil : filterComposition
        if item.videoComposition !== wanted {
            item.videoComposition = wanted
        }
        // A paused player shows its last frame; nudge it so the change appears.
        if !isPlaying, isLoaded {
            seek(to: currentTime, precise: true)
        }
    }

    // MARK: - Observers

    private func handleTick(_ seconds: Double) {
        guard !isScrubbing, seconds.isFinite else { return }
        currentTime = min(max(seconds, 0), duration)
    }

    private func handleEnd() {
        currentTime = duration
    }

    private func syncPlaying(_ playing: Bool) {
        if playing != isPlaying { isPlaying = playing }
    }
}
