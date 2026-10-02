import CoreGraphics

/// Every fixed dimension used by the interface lives here so that tuning the
/// layout never means hunting for stray numbers in view code.
enum Metrics {
    enum Touch {
        static let minimum: CGFloat = 44
        static let pressedScale: CGFloat = 0.94
        static let pressedOpacity: Double = 0.75
        static let disabledOpacity: Double = 0.5
    }

    /// Spacing scale used between and inside controls.
    enum Space {
        static let hair: CGFloat = 2
        static let tight: CGFloat = 4
        static let snug: CGFloat = 5
        static let close: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
        static let wide: CGFloat = 14
    }

    /// Fixed sizes for chrome text and glyphs.
    enum TypeSize {
        static let micro: CGFloat = 10
        static let caption: CGFloat = 11
        static let small: CGFloat = 12
        static let label: CGFloat = 13
        static let body: CGFloat = 14
        static let value: CGFloat = 15
        static let glyph: CGFloat = 17
        static let hero: CGFloat = 30
    }

    enum Line {
        static let hairline: CGFloat = 1
        static let reticle: CGFloat = 1.5
        static let needle: CGFloat = 2
        static let selected: CGFloat = 2.5
    }

    enum Badge {
        static let height: CGFloat = 28
        static let padding: CGFloat = 11
        static let dotSize: CGFloat = 7
    }

    enum Shade {
        static let veil: Double = 0.45
        static let shadow: Double = 0.35
        static let grid: Double = 0.42
        static let secondary: Double = 0.75
        static let levelSide: Double = 0.7
        static let recordingRing: Double = 0.9
        static let tickMajor: Double = 0.95
        static let tickMinor: Double = 0.5
        static let tickEdgeFade: CGFloat = 0.85
    }

    enum TopBar {
        static let height: CGFloat = 52
        static let sidePadding: CGFloat = 14
        static let chipHeight: CGFloat = 36
        static let chipPadding: CGFloat = 12
        static let iconSize: CGFloat = 15
        static let labelSize: CGFloat = 13
    }

    enum Deck {
        static let shutterRowHeight: CGFloat = 104
        static let sidePadding: CGFloat = 28
        static let bottomPadding: CGFloat = 4
        static let thumbnailSize: CGFloat = 54
        static let thumbnailCorner: CGFloat = 15
        static let thumbnailEntryScale: CGFloat = 0.8
        static let sideButtonSize: CGFloat = 54
        static let sideIconSize: CGFloat = 20
        static let scrimOpacity: Double = 0.66
        static let scrimFade: CGFloat = 56
    }

    enum Shutter {
        static let diameter: CGFloat = 80
        static let ringWidth: CGFloat = 3
        static let ringDash: CGFloat = 2
        static let ringGap: CGFloat = 4.05
        static let coreInset: CGFloat = 9
        static let pressedScale: CGFloat = 0.9
        static let recordingCoreSize: CGFloat = 30
        static let recordingCorner: CGFloat = 9
        static let glyphSize: CGFloat = 22
    }

    enum Dial {
        static let height: CGFloat = 44
        static let itemWidth: CGFloat = 92
        static let labelSize: CGFloat = 14
        static let markerSize: CGFloat = 5
        static let markerSpacing: CGFloat = 4
        static let markerRestScale: CGFloat = 0.2
        static let snapThreshold: CGFloat = 0.45
        static let maxStepsPerSwipe = 2
        static let rubberBandCoefficient: CGFloat = 0.55
    }

    enum Zoom {
        static let rowHeight: CGFloat = 50
        static let chipSize: CGFloat = 36
        static let selectedChipWidth: CGFloat = 56
        static let spacing: CGFloat = 6
        static let labelSize: CGFloat = 12
        static let dragPointsPerDoubling: CGFloat = 110
        static let maxDisplayZoom: CGFloat = 10
        static let rampRate: Float = 8
        static let viewerStops: [CGFloat] = [1, 2, 3]
        static let stopTolerance: CGFloat = 0.04
    }

    enum Panel {
        static let cornerRadius: CGFloat = 24
        static let outerPadding: CGFloat = 10
        static let bottomGap: CGFloat = 6
        static let innerPadding: CGFloat = 12
        static let tileWidth: CGFloat = 70
        static let tileHeight: CGFloat = 62
        static let tileCorner: CGFloat = 16
        static let tileSpacing: CGFloat = 8
        static let optionHeight: CGFloat = 38
        static let dismissDragDistance: CGFloat = 44
        static let lookTileSize: CGFloat = 58
        static let lookTileCorner: CGFloat = 14
        static let intensityLabelWidth: CGFloat = 44
    }

    enum Ruler {
        static let height: CGFloat = 34
        static let tickSpacing: CGFloat = 9
        static let majorHeight: CGFloat = 18
        static let minorHeight: CGFloat = 9
        static let needleHeight: CGFloat = 26
    }

    enum Stage {
        static let frameCornerRadius: CGFloat = 22
        static let borderWidth: CGFloat = 1
        static let gridLineWidth: CGFloat = 0.75
        static let focusReticleSize: CGFloat = 78
        static let levelSegment: CGFloat = 56
        static let levelGap: CGFloat = 10
        static let levelTolerance: Double = 1.0
        static let levelFlatThreshold: Double = 0.88
        static let countdownSize: CGFloat = 120
        static let countdownShadowRadius: CGFloat = 12
        static let levelSideRatio: CGFloat = 0.4
        static let levelThickness: CGFloat = 2
        static let focusDotSize: CGFloat = 4
        static let focusEntryScale: CGFloat = 1.35
        static let messageButtonPadding: CGFloat = 22
    }

    enum Viewer {
        static let maxRelativeZoom: CGFloat = 6
        static let doubleTapRelativeZoom: CGFloat = 2.5
        static let zoomReportThreshold: CGFloat = 0.01
    }

    enum Transport {
        static let height: CGFloat = 46
        static let trackHeight: CGFloat = 4
        static let thumbSize: CGFloat = 16
        static let thumbActiveScale: CGFloat = 1.25
        static let sidePadding: CGFloat = 14
        static let bottomGap: CGFloat = 10
        static let seekTolerance: Double = 0.05
        static let skipInterval: Double = 5
    }

    enum Media {
        static let displayOversample: CGFloat = 1.5
        static let maxDisplayPixel: CGFloat = 4096
        static let reducedDisplayPixel: CGFloat = 2048
        static let exportMaxPixel: CGFloat = 4032
        static let thumbnailPixel: CGFloat = 180
        static let lookPreviewPixel: CGFloat = 200
        static let draftScale: CGFloat = 0.5
        static let exportQuality: Double = 0.92
    }

    enum Exposure {
        static let range: ClosedRange<Double> = -2...2
        static let step: Double = 0.1
        static let majorEvery = 5
    }

    enum Notice {
        static let duration: Double = 2.6
        static let topGap: CGFloat = 10
        static let verticalPadding: CGFloat = 9
    }
}
