#if DEBUG
import Combine
import QuartzCore
import UIKit

/// Measures the display's real frame rate with a display link.
@MainActor
final class FPSMonitor: NSObject, ObservableObject {
    @Published private(set) var framesPerSecond = 0

    private var link: CADisplayLink?
    private var windowStart: CFTimeInterval = 0
    private var frameCount = 0
    private let window: CFTimeInterval = 0.5

    func start() {
        guard link == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // Ask for the fastest rate the display offers, so ProMotion shows as 120.
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    func stop() {
        link?.invalidate()
        link = nil
        frameCount = 0
        windowStart = 0
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        let now = displayLink.timestamp
        if windowStart == 0 {
            windowStart = now
            return
        }
        frameCount += 1
        let elapsed = now - windowStart
        guard elapsed >= window else { return }
        framesPerSecond = Int((Double(frameCount) / elapsed).rounded())
        frameCount = 0
        windowStart = now
    }
}
#endif
