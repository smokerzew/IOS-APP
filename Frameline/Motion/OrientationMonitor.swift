import Combine
import SwiftUI
import UIKit

/// The interface stays portrait, as a camera's does; glyphs turn to face the
/// reader and captures are tagged with the way the phone is actually held.
@MainActor
final class OrientationMonitor: ObservableObject {
    @Published private(set) var glyphAngle: Angle = .zero
    /// Rotation, in degrees, to apply to captured video and photos.
    private(set) var captureRotationAngle: CGFloat = 90

    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        refresh()
    }

    func stop() {
        guard let observer else { return }
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func refresh() {
        switch UIDevice.current.orientation {
        case .portrait:
            glyphAngle = .zero
            captureRotationAngle = 90
        case .landscapeLeft:
            glyphAngle = .degrees(90)
            captureRotationAngle = 0
        case .landscapeRight:
            glyphAngle = .degrees(-90)
            captureRotationAngle = 180
        case .portraitUpsideDown:
            glyphAngle = .degrees(180)
            captureRotationAngle = 270
        default:
            break
        }
    }
}
