import CoreGraphics
import Foundation

/// Turns the end of a drag into a direction, or nothing. Shared by the Watch
/// pad and the phone's local fallback so both feel the same.
struct SwipeClassifier: Sendable {
    /// Shorter drags are treated as an accidental brush and ignored.
    var minimumDistance: CGFloat = 24
    /// A short but fast flick still counts if it would have travelled this far.
    var minimumPredictedDistance: CGFloat = 60
    /// The dominant axis must beat the other by this factor. Anything closer
    /// to the diagonal is ambiguous, and a wrong direction is worse than none.
    var axisDominance: CGFloat = 1.3

    struct Reading: Sendable {
        let direction: SwipeDirection
        let distance: CGFloat
        let speed: CGFloat
    }

    func classify(translation: CGSize, predictedEnd: CGSize, velocity: CGSize) -> Reading? {
        let dx = abs(translation.width)
        let dy = abs(translation.height)

        let horizontal: Bool
        if dx >= dy * axisDominance {
            horizontal = true
        } else if dy >= dx * axisDominance {
            horizontal = false
        } else {
            return nil
        }

        let travelled = horizontal ? dx : dy
        let predicted = horizontal ? abs(predictedEnd.width) : abs(predictedEnd.height)
        guard travelled >= minimumDistance || predicted >= minimumPredictedDistance else {
            return nil
        }

        let signed = horizontal ? translation.width : translation.height
        let direction: SwipeDirection = horizontal
            ? (signed > 0 ? .right : .left)
            : (signed > 0 ? .down : .up)
        let speed = horizontal ? abs(velocity.width) : abs(velocity.height)
        return Reading(direction: direction, distance: travelled, speed: speed)
    }
}
