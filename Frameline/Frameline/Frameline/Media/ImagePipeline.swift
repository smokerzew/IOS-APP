import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// Decodes images at the size they are needed. Full-resolution pixels are
/// never held in memory just to be shown on screen.
enum ImagePipeline {
    /// Decodes `url` so its longest side is at most `maxPixel`, upright.
    static func downsample(url: URL, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return thumbnail(from: source, maxPixel: maxPixel)
    }

    static func thumbnail(from data: Data, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        return thumbnail(from: source, maxPixel: maxPixel)
    }

    private static func thumbnail(from source: CGImageSource, maxPixel: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(Int(maxPixel), 1)
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Displayed pixel size of an image file without decoding it.
    static func displaySize(ofImageAt url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int,
              pixelWidth > 0, pixelHeight > 0 else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation as String] as? Int) ?? 1
        // EXIF orientations 5 to 8 are rotated a quarter turn.
        let isQuarterTurned = orientation >= 5 && orientation <= 8
        let width = CGFloat(isQuarterTurned ? pixelHeight : pixelWidth)
        let height = CGFloat(isQuarterTurned ? pixelWidth : pixelHeight)
        return CGSize(width: width, height: height)
    }

    /// A small still from the start of a video, for thumbnails and look previews.
    static func poster(forVideoAt url: URL, maxPixel: CGFloat) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        return try? await generator.image(at: .zero).image
    }
}
