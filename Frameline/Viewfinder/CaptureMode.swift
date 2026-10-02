import CoreGraphics
import Foundation

/// The three things Frameline can show in its viewfinder.
enum CaptureMode: String, CaseIterable, Identifiable {
    /// A photo or video imported from the Photos library.
    case library
    /// Live still capture from the camera.
    case photo
    /// Live video recording from the camera.
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Library"
        case .photo: return "Photo"
        case .video: return "Video"
        }
    }

    var usesCamera: Bool { self != .library }
}

enum FrameAspect: String, CaseIterable, Identifiable {
    case square
    case fourThree
    case sixteenNine

    var id: String { rawValue }

    var label: String {
        switch self {
        case .square: return "1:1"
        case .fourThree: return "4:3"
        case .sixteenNine: return "16:9"
        }
    }

    var spokenLabel: String {
        switch self {
        case .square: return "Square"
        case .fourThree: return "4 by 3"
        case .sixteenNine: return "16 by 9"
        }
    }

    /// Height divided by width of the portrait frame.
    var heightOverWidth: CGFloat {
        switch self {
        case .square: return 1
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        }
    }
}

enum FlashSetting: String, CaseIterable, Identifiable {
    case auto
    case on
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }

    var next: FlashSetting {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }
}

enum TimerSetting: Int, CaseIterable, Identifiable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var label: String { self == .off ? "Off" : "\(rawValue)s" }

    var spokenLabel: String { self == .off ? "Off" : "\(rawValue) seconds" }
}

enum CameraFacing: String {
    case back
    case front
}

/// Entries of the expandable controls panel.
enum ControlKind: String, CaseIterable, Identifiable {
    case flash
    case aspect
    case timer
    case exposure
    case look
    case grid
    case level

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash: return "Flash"
        case .aspect: return "Aspect"
        case .timer: return "Timer"
        case .exposure: return "Exposure"
        case .look: return "Look"
        case .grid: return "Grid"
        case .level: return "Level"
        }
    }

    var symbol: String {
        switch self {
        case .flash: return "bolt.fill"
        case .aspect: return "aspectratio"
        case .timer: return "timer"
        case .exposure: return "plusminus.circle"
        case .look: return "camera.filters"
        case .grid: return "grid"
        case .level: return "level"
        }
    }
}
