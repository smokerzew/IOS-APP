import AVFoundation
import SwiftUI
import UIKit

/// Shows an AVPlayer's picture. The stage sizes this view to the video's own
/// aspect, so the picture is never stretched.
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.backgroundColor = .black
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // The layer class is fixed above, so this cast cannot fail.
        layer as! AVPlayerLayer
    }
}
