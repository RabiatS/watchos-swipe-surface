import Foundation

/// The direction a flick travelled on the sender's screen. A tap is included
/// because "select" is the one non-swipe every remote needs.
enum SwipeDirection: String, Codable, Sendable, CaseIterable {
    case up, down, left, right, tap

    var title: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .tap: "Tap"
        }
    }

    var symbolName: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .tap: "hand.tap"
        }
    }

    var mirroredHorizontally: SwipeDirection {
        switch self {
        case .left: .right
        case .right: .left
        default: self
        }
    }
}

/// Where a swipe was made. The phone accepts its own swipes so the pipeline
/// can be exercised without a Watch nearby.
enum SwipeSource: String, Codable, Sendable {
    case watch, phone

    var title: String {
        switch self {
        case .watch: "Watch"
        case .phone: "Phone"
        }
    }
}

/// One flick, as it crosses the link. Small on purpose: WatchConnectivity
/// messages are cheap but not free, and nothing here needs more than this.
struct SwipeEvent: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let direction: SwipeDirection
    /// Points travelled along the dominant axis between touch down and release.
    let distance: Double
    /// Points per second along the dominant axis at release.
    let speed: Double
    /// Sender's clock at the moment of release. Used for latency on the phone.
    let sentAt: Date
    let source: SwipeSource

    init(direction: SwipeDirection, distance: Double = 0, speed: Double = 0,
         source: SwipeSource, sentAt: Date = .now) {
        self.id = UUID()
        self.direction = direction
        self.distance = distance
        self.speed = speed
        self.sentAt = sentAt
        self.source = source
    }
}
