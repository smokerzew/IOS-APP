import Combine
import Foundation

/// Builds the app's long-lived objects once and hands them to the view tree.
@MainActor
final class AppEnvironment: ObservableObject {
    let preferences: Preferences
    let haptics: HapticManager
    let camera: CameraService
    let media: MediaStore
    let level: LevelMonitor
    let orientation: OrientationMonitor
    let model: ViewfinderModel

    init() {
        let preferences = Preferences()
        let haptics = HapticManager()
        let camera = CameraService(facing: preferences.facing)
        let media = MediaStore(preferences: preferences)
        let level = LevelMonitor()
        let orientation = OrientationMonitor()

        self.preferences = preferences
        self.haptics = haptics
        self.camera = camera
        self.media = media
        self.level = level
        self.orientation = orientation
        self.model = ViewfinderModel(
            preferences: preferences,
            camera: camera,
            media: media,
            level: level,
            orientation: orientation,
            haptics: haptics
        )
    }
}
