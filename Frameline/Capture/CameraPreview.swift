import AVFoundation
import SwiftUI
import UIKit

/// Live camera preview. Gestures are UIKit recognisers so pinches track the
/// fingers exactly and taps can be converted to capture-device coordinates.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Device point (0...1) and the tapped location inside the preview view.
    let onTap: (CGPoint, CGPoint) -> Void
    /// Cumulative pinch scale and whether the pinch just began.
    let onPinch: (CGFloat, Bool) -> Void
    /// -1 for a swipe towards the leading edge, +1 towards the trailing edge.
    let onSwipe: (Int) -> Void

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.installGestures()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        apply(to: uiView)
    }

    private func apply(to view: PreviewHostView) {
        view.onTap = onTap
        view.onPinch = onPinch
        view.onSwipe = onSwipe
        view.alignPreviewToPortrait()
    }
}

final class PreviewHostView: UIView {
    var onTap: ((CGPoint, CGPoint) -> Void)?
    var onPinch: ((CGFloat, Bool) -> Void)?
    var onSwipe: ((Int) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // The layer class is fixed above, so this cast cannot fail.
        layer as! AVCaptureVideoPreviewLayer
    }

    private let portraitRotationAngle: CGFloat = 90

    func installGestures() {
        isAccessibilityElement = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipe.direction = direction
            addGestureRecognizer(swipe)
        }
    }

    /// The interface is portrait-only, so the preview is always shown upright.
    func alignPreviewToPortrait() {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(portraitRotationAngle),
              connection.videoRotationAngle != portraitRotationAngle else { return }
        connection.videoRotationAngle = portraitRotationAngle
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        alignPreviewToPortrait()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        onTap?(devicePoint, location)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            onPinch?(recognizer.scale, true)
        case .changed:
            onPinch?(recognizer.scale, false)
        default:
            break
        }
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        onSwipe?(recognizer.direction == .left ? 1 : -1)
    }
}
