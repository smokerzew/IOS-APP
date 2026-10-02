import SwiftUI
import UIKit

/// A request to move the viewer to a zoom level relative to "fills the frame".
struct ZoomRequest: Equatable {
    let id: Int
    let factor: CGFloat
    let animated: Bool
}

/// Imported photo with native pinch, pan and double-tap zoom.
///
/// The scroll view always covers the whole screen; the visible frame is passed
/// in as `viewport` insets. Changing aspect ratio therefore only changes the
/// insets, and the picture keeps its centre while the frame animates around it.
struct ZoomableImageView: UIViewRepresentable {
    let photo: StagePhoto
    let viewport: UIEdgeInsets
    let zoomRequest: ZoomRequest?
    let reduceMotion: Bool
    let onZoomChange: (CGFloat) -> Void
    let onVisibleRectChange: (CGRect) -> Void
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ZoomingScrollView {
        let view = ZoomingScrollView(frame: .zero)
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: ZoomingScrollView, context: Context) {
        configure(uiView, coordinator: context.coordinator)
    }

    private func configure(_ view: ZoomingScrollView, coordinator: Coordinator) {
        view.onZoomChange = onZoomChange
        view.onVisibleRectChange = onVisibleRectChange
        view.onSingleTap = onSingleTap
        view.reduceMotion = reduceMotion
        view.display(photo)
        view.setViewport(viewport, animated: true)
        if let request = zoomRequest, request.id != coordinator.lastZoomRequestID {
            coordinator.lastZoomRequestID = request.id
            view.setRelativeZoom(request.factor, animated: request.animated)
        }
    }

    final class Coordinator {
        var lastZoomRequestID = 0
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    var onZoomChange: ((CGFloat) -> Void)?
    var onVisibleRectChange: ((CGRect) -> Void)?
    var onSingleTap: (() -> Void)?
    var reduceMotion = false

    private let imageView = UIImageView()
    private var shownPhoto: StagePhoto?
    private var imageSize: CGSize = .zero
    private var viewport: UIEdgeInsets = .zero
    private var laidOutSize: CGSize = .zero
    private var reportedZoom: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        backgroundColor = .black
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        alwaysBounceVertical = true
        alwaysBounceHorizontal = true
        bouncesZoom = true
        scrollsToTop = false

        imageView.contentMode = .scaleToFill
        imageView.isAccessibilityElement = false
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    // MARK: - Content

    func display(_ photo: StagePhoto) {
        guard photo != shownPhoto else { return }
        let isNewMedia = photo.mediaID != shownPhoto?.mediaID
        shownPhoto = photo
        let image = photo.image.image

        if isNewMedia {
            imageView.image = image
            imageSize = image.size
            resetGeometry()
        } else if photo.crossfade, !reduceMotion {
            UIView.transition(
                with: imageView,
                duration: Motion.Duration.crossfade,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: { self.imageView.image = image },
                completion: nil
            )
        } else {
            imageView.image = image
        }
    }

    /// Changes the visible frame, keeping the same point of the picture at the
    /// frame's centre and the same zoom relative to "fills the frame".
    func setViewport(_ insets: UIEdgeInsets, animated: Bool) {
        guard insets != viewport else { return }
        guard imageSize != .zero, laidOutSize != .zero else {
            viewport = insets
            return
        }
        let relativeZoom = zoomScale / max(minimumZoomScale, .leastNonzeroMagnitude)
        let anchor = contentPointAtViewportCenter()
        viewport = insets

        let changes = {
            self.applyGeometry(relativeZoom: relativeZoom, anchor: anchor)
        }
        if animated, !reduceMotion {
            UIView.animate(
                withDuration: Motion.Duration.frame,
                delay: 0,
                usingSpringWithDamping: CGFloat(Motion.Spring.frameDamping),
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: changes,
                completion: nil
            )
        } else {
            changes()
        }
    }

    func setRelativeZoom(_ factor: CGFloat, animated: Bool) {
        guard imageSize != .zero else { return }
        let target = min(max(minimumZoomScale * factor, minimumZoomScale), maximumZoomScale)
        zoom(to: target, keeping: contentPointAtViewportCenter(), at: viewportCenter, animated: animated)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        resetGeometry()
    }

    private var viewportSize: CGSize {
        CGSize(
            width: max(bounds.width - viewport.left - viewport.right, 1),
            height: max(bounds.height - viewport.top - viewport.bottom, 1)
        )
    }

    private var viewportCenter: CGPoint {
        CGPoint(x: viewport.left + viewportSize.width / 2, y: viewport.top + viewportSize.height / 2)
    }

    /// Scale at which the picture exactly fills the viewport.
    private var fillScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
    }

    private func resetGeometry() {
        guard imageSize != .zero, bounds.width > 0, bounds.height > 0 else { return }
        minimumZoomScale = 1
        maximumZoomScale = 1
        zoomScale = 1
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        contentSize = imageSize
        applyGeometry(relativeZoom: 1, anchor: CGPoint(x: imageSize.width / 2, y: imageSize.height / 2))
    }

    private func applyGeometry(relativeZoom: CGFloat, anchor: CGPoint) {
        let fill = fillScale
        minimumZoomScale = fill
        maximumZoomScale = fill * Metrics.Viewer.maxRelativeZoom
        contentInset = viewport
        let scale = min(max(fill * relativeZoom, fill), maximumZoomScale)
        zoomScale = scale
        contentOffset = clampedOffset(offset(placing: anchor, at: viewportCenter, scale: scale), scale: scale)
        report()
    }

    private func contentPointAtViewportCenter() -> CGPoint {
        let scale = max(zoomScale, .leastNonzeroMagnitude)
        let center = viewportCenter
        return CGPoint(x: (contentOffset.x + center.x) / scale, y: (contentOffset.y + center.y) / scale)
    }

    private func offset(placing contentPoint: CGPoint, at viewPoint: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: contentPoint.x * scale - viewPoint.x, y: contentPoint.y * scale - viewPoint.y)
    }

    private func clampedOffset(_ offset: CGPoint, scale: CGFloat) -> CGPoint {
        let minX = -viewport.left
        let minY = -viewport.top
        let maxX = max(minX, imageSize.width * scale - bounds.width + viewport.right)
        let maxY = max(minY, imageSize.height * scale - bounds.height + viewport.bottom)
        return CGPoint(x: min(max(offset.x, minX), maxX), y: min(max(offset.y, minY), maxY))
    }

    private func zoom(to scale: CGFloat, keeping contentPoint: CGPoint, at viewPoint: CGPoint, animated: Bool) {
        let changes = {
            self.zoomScale = scale
            self.contentOffset = self.clampedOffset(
                self.offset(placing: contentPoint, at: viewPoint, scale: scale),
                scale: scale
            )
        }
        if animated, !reduceMotion {
            UIView.animate(
                withDuration: Motion.Duration.frame,
                delay: 0,
                usingSpringWithDamping: CGFloat(Motion.Spring.frameDamping),
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: changes,
                completion: { _ in self.report() }
            )
        } else {
            changes()
            report()
        }
    }

    // MARK: - Gestures

    /// Zooms in around the tapped point, or back out if already zoomed.
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard imageSize != .zero else { return }
        let isZoomed = zoomScale > minimumZoomScale * (1 + Metrics.Viewer.zoomReportThreshold)
        let target = isZoomed ? minimumZoomScale : minimumZoomScale * Metrics.Viewer.doubleTapRelativeZoom
        let contentPoint = recognizer.location(in: imageView)
        let location = recognizer.location(in: self)
        let viewPoint = CGPoint(x: location.x - bounds.origin.x, y: location.y - bounds.origin.y)
        zoom(to: target, keeping: contentPoint, at: isZoomed ? viewportCenter : viewPoint, animated: true)
    }

    @objc private func handleSingleTap() {
        onSingleTap?()
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        report()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        report()
    }

    // MARK: - Reporting

    private func report() {
        guard imageSize.width > 0, imageSize.height > 0, zoomScale > 0, minimumZoomScale > 0 else { return }

        let scale = zoomScale
        let size = viewportSize
        let visible = CGRect(
            x: (contentOffset.x + viewport.left) / scale / imageSize.width,
            y: (contentOffset.y + viewport.top) / scale / imageSize.height,
            width: size.width / scale / imageSize.width,
            height: size.height / scale / imageSize.height
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        onVisibleRectChange?(visible)

        let relative = scale / minimumZoomScale
        guard abs(relative - reportedZoom) >= Metrics.Viewer.zoomReportThreshold else { return }
        reportedZoom = relative
        // Delivered on the next turn so a report made during a SwiftUI update
        // never changes state in the middle of that update.
        Task { @MainActor [weak self] in
            self?.onZoomChange?(relative)
        }
    }
}
