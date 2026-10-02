import SwiftUI
import UIKit

/// Connects system lifecycle events to the model: foreground and background,
/// lock and unlock, and memory pressure. The app does no work in the
/// background and does not try to outlive suspension.
struct SceneLifecycle: ViewModifier {
    let model: ViewfinderModel

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    model.sceneBecameActive()
                case .inactive:
                    model.sceneWillResignActive()
                case .background:
                    model.sceneDidEnterBackground()
                @unknown default:
                    break
                }
            }
            .onAppear {
                if scenePhase == .active { model.sceneBecameActive() }
            }
            // Locking the device makes protected data unavailable; treat it
            // like backgrounding so the camera and sensors are released.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                model.sceneDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                if scenePhase == .active { model.sceneBecameActive() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                model.memoryWarningReceived()
            }
    }
}
