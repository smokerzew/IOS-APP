import SwiftUI

/// Animation presets. Every preset has a Reduce Motion form that keeps the
/// state change but drops the large movement.
enum Motion {
    enum Duration {
        static let crossfade: Double = 0.22
        static let frame: Double = 0.5
        static let blink: Double = 0.09
        static let reduced: Double = 0.18
        static let focus: Double = 1.1
        static let level: Double = 0.1
        static let scrubThumb: Double = 0.12
    }

    enum Spring {
        static let frameResponse: Double = 0.46
        static let frameDamping: Double = 0.86
    }

    static func frame(_ reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: Duration.reduced)
            : .spring(response: Spring.frameResponse, dampingFraction: Spring.frameDamping)
    }

    static func panel(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: Duration.reduced) : .spring(response: 0.38, dampingFraction: 0.84)
    }

    static func dial(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: Duration.reduced) : .spring(response: 0.34, dampingFraction: 0.8)
    }

    static func press(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.22, dampingFraction: 0.62)
    }

    static func selection(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: Duration.reduced) : .spring(response: 0.3, dampingFraction: 0.78)
    }

    static let fade = Animation.easeOut(duration: Duration.crossfade)
}
