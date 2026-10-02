import CoreGraphics
import CoreImage
import Foundation

/// Applies an `Appearance` with Core Image. The same filter chain is used for
/// stills, for video frames during playback and for exported copies.
final class LookRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])

    /// Builds the filter chain. Nothing is rendered until the result is drawn.
    static func apply(_ appearance: Appearance, to input: CIImage) -> CIImage {
        var image = input

        if abs(appearance.exposure) > 0.001 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: appearance.exposure])
        }

        let look = appearance.look
        let amount = min(max(appearance.intensity, 0), 1)
        guard !look.isOriginal, amount > 0.001 else { return image }

        let temperature = blend(Look.neutralTemperature, look.temperature, amount)
        let tint = blend(0, look.tint, amount)
        if abs(temperature - Look.neutralTemperature) > 1 || abs(tint) > 0.1 {
            image = image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: CGFloat(temperature), y: CGFloat(tint)),
                "inputTargetNeutral": CIVector(x: CGFloat(Look.neutralTemperature), y: 0)
            ])
        }

        image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: blend(1, look.saturation, amount),
            kCIInputContrastKey: blend(1, look.contrast, amount),
            kCIInputBrightnessKey: blend(0, look.brightness, amount)
        ])

        let vibrance = blend(0, look.vibrance, amount)
        if vibrance > 0.001 {
            image = image.applyingFilter("CIVibrance", parameters: ["inputAmount": vibrance])
        }

        let fade = blend(0, look.fade, amount)
        if fade > 0.001 {
            image = image.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: CGFloat(0.12 * fade)),
                "inputPoint1": CIVector(x: 0.25, y: CGFloat(0.25 + 0.05 * fade)),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: CGFloat(0.75 - 0.02 * fade)),
                "inputPoint4": CIVector(x: 1, y: CGFloat(1 - 0.05 * fade))
            ])
        }

        let vignette = blend(0, look.vignette, amount)
        if vignette > 0.001 {
            image = image.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: vignette,
                kCIInputRadiusKey: 1.6
            ])
        }

        return image
    }

    /// Renders `base` with the appearance applied. A `scale` below 1 produces a
    /// smaller draft, used while a slider is moving.
    func render(_ base: CGImage, appearance: Appearance, scale: CGFloat) -> CGImage? {
        var image = CIImage(cgImage: base)
        if scale < 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let extent = image.extent.integral
        let output = Self.apply(appearance, to: image)
        return context.createCGImage(output, from: extent, format: .RGBA8, colorSpace: Self.outputColorSpace(for: base))
    }

    /// Encodes a styled image for saving. HEIF where available, JPEG otherwise.
    func encode(_ image: CIImage, like base: CGImage) -> Data? {
        let colorSpace = Self.outputColorSpace(for: base)
        if let heif = context.heifRepresentation(of: image, format: .RGBA8, colorSpace: colorSpace, options: [:]) {
            return heif
        }
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [:])
    }

    func clearCaches() {
        context.clearCaches()
    }

    private static func blend(_ from: Double, _ to: Double, _ amount: Double) -> Double {
        from + (to - from) * amount
    }

    private static func outputColorSpace(for image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb {
            return space
        }
        return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }
}
