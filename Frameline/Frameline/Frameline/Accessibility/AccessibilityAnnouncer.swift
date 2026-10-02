import UIKit

/// Spoken feedback for events that have no focused element to describe them.
@MainActor
enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

/// Identifiers used by UI tests and the visual regression matrix.
enum AccessibilityID {
    static let shutter = "viewfinder.shutter"
    static let modeDial = "viewfinder.modeDial"
    static let flash = "viewfinder.flash"
    static let controlsToggle = "viewfinder.controlsToggle"
    static let controlsPanel = "viewfinder.controlsPanel"
    static let status = "viewfinder.status"
    static let thumbnail = "viewfinder.thumbnail"
    static let sideButton = "viewfinder.sideButton"
    static let stage = "viewfinder.stage"
    static let zoom = "viewfinder.zoom"
    static let scrubber = "viewfinder.scrubber"
    static let exposure = "viewfinder.exposure"

    static func control(_ kind: ControlKind) -> String { "viewfinder.control.\(kind.rawValue)" }
    static func option(_ name: String) -> String { "viewfinder.option.\(name)" }
}
