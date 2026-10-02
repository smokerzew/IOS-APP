import Combine
import CoreMotion
import Foundation

/// Reads the device's roll from the motion sensors for the level overlay.
/// Runs only while the level is visible.
@MainActor
final class LevelMonitor: ObservableObject {
    /// Degrees away from the nearest upright or sideways position.
    @Published private(set) var offsetDegrees: Double = 0
    @Published private(set) var isLevel = false
    /// False while the phone lies flat, where roll has no meaning.
    @Published private(set) var isMeaningful = false

    var onLevelLocked: (() -> Void)?

    private let manager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 30.0
    private let smoothing = 0.25

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            let x = gravity.x
            let y = gravity.y
            let z = gravity.z
            MainActor.assumeIsolated {
                self?.update(x: x, y: y, z: z)
            }
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        isMeaningful = false
        isLevel = false
    }

    private func update(x: Double, y: Double, z: Double) {
        let meaningful = abs(z) < Metrics.Stage.levelFlatThreshold
        if meaningful != isMeaningful { isMeaningful = meaningful }
        guard meaningful else {
            if isLevel { isLevel = false }
            return
        }

        let degrees = atan2(x, -y) * 180 / .pi
        let nearestQuarter = (degrees / 90).rounded() * 90
        let target = degrees - nearestQuarter
        let smoothed = offsetDegrees + (target - offsetDegrees) * smoothing
        if abs(smoothed - offsetDegrees) > 0.02 { offsetDegrees = smoothed }

        let level = abs(smoothed) < Metrics.Stage.levelTolerance
        if level != isLevel {
            isLevel = level
            if level { onLevelLocked?() }
        }
    }
}
