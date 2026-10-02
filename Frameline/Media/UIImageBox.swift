import UIKit

/// Reference wrapper so a rendered image can be compared by identity.
final class UIImageBox {
    let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }
}
