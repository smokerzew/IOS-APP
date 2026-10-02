import PhotosUI
import SwiftUI

/// The whole interface: the stage with the picture, and the chrome over it.
struct ViewfinderScreen: View {
    @EnvironmentObject private var model: ViewfinderModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pickerItem: PhotosPickerItem?
    #if DEBUG
    @StateObject private var debug = DebugSettings()
    #endif

    var body: some View {
        GeometryReader { proxy in
            let layout = ViewfinderLayout(size: proxy.size, insets: proxy.safeAreaInsets)
            ZStack {
                StageView(layout: layout)

                chrome(layout)
                    .opacity(model.isImmersive ? 0 : 1)
                    .allowsHitTesting(!model.isImmersive)

                if let notice = model.notice {
                    NoticeBanner(notice: notice)
                        .position(
                            x: layout.size.width / 2,
                            y: layout.topBarRect.maxY + Metrics.Notice.topGap + Metrics.TopBar.chipHeight / 2
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(2)
                }

                #if DEBUG
                DebugOverlay(layout: layout, settings: debug)
                    .zIndex(3)
                #endif
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .animation(Motion.panel(reduceMotion), value: model.notice)
            .animation(Motion.frame(reduceMotion), value: model.isImmersive)
        }
        .ignoresSafeArea()
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .photosPicker(
            isPresented: $model.isPickerPresented,
            selection: $pickerItem,
            matching: .any(of: [.images, .videos]),
            preferredItemEncoding: .current
        )
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            model.importPicked(item)
        }
    }

    private func chrome(_ layout: ViewfinderLayout) -> some View {
        VStack(spacing: 0) {
            TopBar()
                .frame(height: Metrics.TopBar.height)
                .padding(.top, layout.insets.top)
            Spacer(minLength: 0)
            BottomDeck(layout: layout)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
