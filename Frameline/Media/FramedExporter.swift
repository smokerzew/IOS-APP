import CoreGraphics
import CoreImage
import Foundation

/// Renders the part of an imported photo that is inside the frame, with the
/// current look, as a new image file. The copy is a fresh render: it carries no
/// camera, date or location metadata, because none of that would be true of it.
enum FramedExporter {
    /// - Parameter visibleRect: Visible region in unit coordinates, origin top-left.
    static func render(
        _ media: ImportedMedia,
        visibleRect: CGRect,
        appearance: Appearance,
        renderer: LookRenderer
    ) -> Data? {
        guard media.kind == .photo,
              let full = ImagePipeline.downsample(url: media.url, maxPixel: Metrics.Media.exportMaxPixel) else {
            return nil
        }
        let width = CGFloat(full.width)
        let height = CGFloat(full.height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let crop = CGRect(
            x: visibleRect.minX * width,
            y: visibleRect.minY * height,
            width: visibleRect.width * width,
            height: visibleRect.height * height
        ).integral.intersection(bounds)

        guard !crop.isEmpty, let cropped = full.cropping(to: crop) else { return nil }
        let styled = LookRenderer.apply(appearance, to: CIImage(cgImage: cropped))
        return renderer.encode(styled, like: cropped)
    }
}
