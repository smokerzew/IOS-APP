import CoreGraphics

/// Small pieces of gesture physics shared by the mode dial and the panels.
enum SpringPhysics {
    /// Lets a dragged value travel past its limits with increasing resistance.
    static func rubberBand(
        _ offset: CGFloat,
        lower: CGFloat,
        upper: CGFloat,
        dimension: CGFloat,
        coefficient: CGFloat
    ) -> CGFloat {
        if offset > upper {
            return upper + resisted(offset - upper, dimension: dimension, coefficient: coefficient)
        }
        if offset < lower {
            return lower - resisted(lower - offset, dimension: dimension, coefficient: coefficient)
        }
        return offset
    }

    private static func resisted(_ overshoot: CGFloat, dimension: CGFloat, coefficient: CGFloat) -> CGFloat {
        guard dimension > 0 else { return 0 }
        return (1 - (1 / ((overshoot * coefficient / dimension) + 1))) * dimension
    }

    /// Converts a projected drag distance into a whole number of item steps.
    /// A drag that stops short of `threshold` items returns 0 and snaps back;
    /// a fast flick projects farther and can cross more than one item.
    static func steps(projected: CGFloat, itemWidth: CGFloat, threshold: CGFloat, limit: Int) -> Int {
        guard itemWidth > 0 else { return 0 }
        let ratio = projected / itemWidth
        guard abs(ratio) >= threshold else { return 0 }
        let magnitude = max(1, min(Int(abs(ratio).rounded()), limit))
        return ratio < 0 ? -magnitude : magnitude
    }
}
