import Foundation
import ImageIO

/// Crops a captured photo to the selected frame aspect, keeping the original
/// container type and the metadata the camera wrote.
enum PhotoCropper {
    static func crop(_ data: Data, to aspect: FrameAspect) -> Data? {
        guard aspect != .fourThree,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let type = CGImageSourceGetType(source) else { return nil }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longSide = max(width, height)
        let shortSide = min(width, height)
        let target = aspect.heightOverWidth

        var croppedLong = longSide
        var croppedShort = shortSide
        if longSide / shortSide > target {
            croppedLong = shortSide * target
        } else {
            croppedShort = longSide / target
        }

        // A centred crop is symmetric, so it is correct whichever way the
        // sensor data is oriented.
        let cropWidth = (width >= height ? croppedLong : croppedShort).rounded(.down)
        let cropHeight = (width >= height ? croppedShort : croppedLong).rounded(.down)
        let rect = CGRect(
            x: ((width - cropWidth) / 2).rounded(.down),
            y: ((height - cropHeight) / 2).rounded(.down),
            width: cropWidth,
            height: cropHeight
        )
        guard let cropped = image.cropping(to: rect) else { return nil }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        properties[kCGImagePropertyPixelWidth as String] = cropped.width
        properties[kCGImagePropertyPixelHeight as String] = cropped.height
        if var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exif[kCGImagePropertyExifPixelXDimension as String] = cropped.width
            exif[kCGImagePropertyExifPixelYDimension as String] = cropped.height
            properties[kCGImagePropertyExifDictionary as String] = exif
        }
        properties[kCGImageDestinationLossyCompressionQuality as String] = Metrics.Media.exportQuality

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cropped, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
