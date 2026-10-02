#if DEBUG
import Combine
import UIKit

/// Developer-only switches for the measurement overlay. This whole folder is
/// compiled out of Release builds.
@MainActor
final class DebugSettings: ObservableObject {
    @Published var isPanelPresented = false
    @Published var showsHUD = false
    @Published var showsGuides = false
    @Published var showsReference = false
    @Published var referenceImage: UIImage?
    @Published var referenceOpacity: Double = 0.5
    @Published var referenceOffsetX: Double = 0
    @Published var referenceOffsetY: Double = 0
    @Published var referenceScale: Double = 1
}
#endif
