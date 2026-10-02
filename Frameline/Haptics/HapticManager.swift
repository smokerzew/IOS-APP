import CoreHaptics
import QuartzCore
import UIKit

/// One place for all feedback so haptics stay consistent and sparing.
@MainActor
final class HapticManager {
    enum Event {
        case selection
        case detent
        case shutterDown
        case shutterRelease
        case modeChange
        case countdownTick
        case countdownFinal
        case levelLocked
        case success
        case warning
        case error
    }

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private var engine: CHHapticEngine?
    private var lastDetentTime: TimeInterval = 0

    /// Minimum spacing between detent ticks so fast drags do not buzz.
    private let detentInterval: TimeInterval = 0.035

    init() {
        prepareEngine()
    }

    func prepare() {
        selectionGenerator.prepare()
        mediumImpact.prepare()
    }

    func play(_ event: Event) {
        switch event {
        case .selection:
            selectionGenerator.selectionChanged()
        case .detent:
            let now = CACurrentMediaTime()
            guard now - lastDetentTime >= detentInterval else { return }
            lastDetentTime = now
            lightImpact.impactOccurred(intensity: 0.55)
        case .shutterDown:
            lightImpact.impactOccurred(intensity: 0.7)
        case .shutterRelease:
            if !playShutterPattern() {
                rigidImpact.impactOccurred()
            }
        case .modeChange:
            mediumImpact.impactOccurred(intensity: 0.8)
        case .countdownTick:
            lightImpact.impactOccurred()
        case .countdownFinal:
            mediumImpact.impactOccurred()
        case .levelLocked:
            rigidImpact.impactOccurred(intensity: 0.6)
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    /// Stops the Core Haptics engine while the app is not on screen.
    func suspend() {
        engine?.stop(completionHandler: nil)
    }

    // MARK: - Core Haptics

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in
                try? engine?.start()
            }
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    /// A two-part click: a sharp transient followed by a softer settle.
    private func playShutterPattern() -> Bool {
        guard let engine else { return false }
        do {
            let click = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0
            )
            let settle = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.06
            )
            let pattern = try CHHapticPattern(events: [click, settle], parameters: [])
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
}
