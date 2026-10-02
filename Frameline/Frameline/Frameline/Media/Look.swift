import Foundation

/// A named colour treatment. Each look is a set of grading parameters that is
/// blended from neutral by its intensity, so partial strengths stay natural.
struct Look: Identifiable, Equatable {
    let id: String
    let name: String
    /// 1 is unchanged.
    let saturation: Double
    /// 1 is unchanged.
    let contrast: Double
    /// 0 is unchanged.
    let brightness: Double
    /// White point in kelvin; above 6500 warms, below cools.
    let temperature: Double
    let tint: Double
    let vibrance: Double
    /// 0...1, lifts the blacks and softens the highlights.
    let fade: Double
    let vignette: Double

    static let neutralTemperature: Double = 6500

    var isOriginal: Bool { id == Look.original.id }

    static let original = Look(
        id: "original", name: "Original",
        saturation: 1, contrast: 1, brightness: 0,
        temperature: neutralTemperature, tint: 0, vibrance: 0, fade: 0, vignette: 0
    )

    static let all: [Look] = [
        original,
        Look(id: "ember", name: "Ember",
             saturation: 1.08, contrast: 1.06, brightness: 0.01,
             temperature: 7600, tint: 6, vibrance: 0.25, fade: 0.1, vignette: 0.3),
        Look(id: "glacier", name: "Glacier",
             saturation: 0.94, contrast: 1.08, brightness: 0,
             temperature: 5500, tint: -4, vibrance: 0.1, fade: 0.05, vignette: 0.2),
        Look(id: "meadow", name: "Meadow",
             saturation: 1.2, contrast: 1.04, brightness: 0.01,
             temperature: 6300, tint: -10, vibrance: 0.45, fade: 0, vignette: 0),
        Look(id: "velvet", name: "Velvet",
             saturation: 1.12, contrast: 1.18, brightness: -0.02,
             temperature: 6800, tint: 4, vibrance: 0.2, fade: 0, vignette: 0.55),
        Look(id: "linen", name: "Linen",
             saturation: 0.82, contrast: 0.92, brightness: 0.03,
             temperature: 6900, tint: 2, vibrance: 0, fade: 0.7, vignette: 0),
        Look(id: "graphite", name: "Graphite",
             saturation: 0, contrast: 1.05, brightness: 0,
             temperature: neutralTemperature, tint: 0, vibrance: 0, fade: 0.25, vignette: 0.25),
        Look(id: "ink", name: "Ink",
             saturation: 0, contrast: 1.32, brightness: -0.03,
             temperature: neutralTemperature, tint: 0, vibrance: 0, fade: 0, vignette: 0.6)
    ]

    static func named(_ id: String) -> Look {
        all.first { $0.id == id } ?? original
    }
}
