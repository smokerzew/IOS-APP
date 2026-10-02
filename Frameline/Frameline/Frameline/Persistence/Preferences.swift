import Foundation

/// Settings that survive relaunch. Each value is written as soon as it changes,
/// so nothing depends on the app getting time to save before it is suspended.
final class Preferences {
    private enum Key: String {
        case mode = "viewfinder.mode"
        case aspect = "viewfinder.aspect"
        case flash = "viewfinder.flash"
        case timer = "viewfinder.timer"
        case look = "viewfinder.look"
        case lookIntensity = "viewfinder.lookIntensity"
        case grid = "viewfinder.grid"
        case level = "viewfinder.level"
        case facing = "camera.facing"
        case lastMediaFile = "media.lastFile"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var mode: CaptureMode {
        get { CaptureMode(rawValue: string(.mode)) ?? .library }
        set { defaults.set(newValue.rawValue, forKey: Key.mode.rawValue) }
    }

    var aspect: FrameAspect {
        get { FrameAspect(rawValue: string(.aspect)) ?? .fourThree }
        set { defaults.set(newValue.rawValue, forKey: Key.aspect.rawValue) }
    }

    var flash: FlashSetting {
        get { FlashSetting(rawValue: string(.flash)) ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: Key.flash.rawValue) }
    }

    var timer: TimerSetting {
        get { TimerSetting(rawValue: defaults.integer(forKey: Key.timer.rawValue)) ?? .off }
        set { defaults.set(newValue.rawValue, forKey: Key.timer.rawValue) }
    }

    var lookID: String {
        get { string(.look) }
        set { defaults.set(newValue, forKey: Key.look.rawValue) }
    }

    var lookIntensity: Double {
        get {
            guard defaults.object(forKey: Key.lookIntensity.rawValue) != nil else { return 1 }
            return min(max(defaults.double(forKey: Key.lookIntensity.rawValue), 0), 1)
        }
        set { defaults.set(newValue, forKey: Key.lookIntensity.rawValue) }
    }

    var showsGrid: Bool {
        get { defaults.bool(forKey: Key.grid.rawValue) }
        set { defaults.set(newValue, forKey: Key.grid.rawValue) }
    }

    var showsLevel: Bool {
        get { defaults.bool(forKey: Key.level.rawValue) }
        set { defaults.set(newValue, forKey: Key.level.rawValue) }
    }

    var facing: CameraFacing {
        get { CameraFacing(rawValue: string(.facing)) ?? .back }
        set { defaults.set(newValue.rawValue, forKey: Key.facing.rawValue) }
    }

    /// File name (not a full path) of the last imported item inside `ImportStorage`.
    var lastMediaFileName: String? {
        get { defaults.string(forKey: Key.lastMediaFile.rawValue) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.lastMediaFile.rawValue)
            } else {
                defaults.removeObject(forKey: Key.lastMediaFile.rawValue)
            }
        }
    }

    private func string(_ key: Key) -> String {
        defaults.string(forKey: key.rawValue) ?? ""
    }
}
