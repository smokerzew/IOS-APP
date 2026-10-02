import SwiftUI

@main
struct FramelineApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ViewfinderScreen()
                .environmentObject(environment.model)
                .environmentObject(environment.camera)
                .environmentObject(environment.media)
                .environmentObject(environment.media.video)
                .environmentObject(environment.level)
                .environmentObject(environment.orientation)
                .modifier(SceneLifecycle(model: environment.model))
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.accent)
                .dynamicTypeSize(.xSmall ... .xxLarge)
        }
    }
}
