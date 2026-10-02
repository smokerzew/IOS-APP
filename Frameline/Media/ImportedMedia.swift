import CoreGraphics
import Foundation

/// A photo or video the user picked from their library, copied into the app's
/// own storage. The app never claims it was captured here.
struct ImportedMedia: Identifiable, Equatable {
    enum Kind: String {
        case photo
        case video
    }

    let id: UUID
    let kind: Kind
    let url: URL
    /// Size as displayed, after the file's orientation is applied.
    let pixelSize: CGSize
    /// Seconds; zero for photos.
    let duration: Double

    /// Width divided by height.
    var aspect: CGFloat {
        guard pixelSize.height > 0 else { return 1 }
        return pixelSize.width / pixelSize.height
    }
}

/// How imported media is drawn: a look, how strongly it is applied, and a
/// brightness adjustment in stops. These change the picture on screen only.
struct Appearance: Equatable {
    var look: Look
    var intensity: Double
    var exposure: Double

    static let neutral = Appearance(look: .original, intensity: 1, exposure: 0)

    var isNeutral: Bool {
        (look.isOriginal || intensity < 0.001) && abs(exposure) < 0.001
    }
}

/// The image currently shown for an imported photo.
struct StagePhoto: Equatable {
    let mediaID: UUID
    let image: UIImageBox
    let crossfade: Bool

    static func == (lhs: StagePhoto, rhs: StagePhoto) -> Bool {
        lhs.mediaID == rhs.mediaID && lhs.image === rhs.image
    }
}
