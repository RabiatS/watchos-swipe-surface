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

    /// What the phone does with this direction. Kept next to the direction so
    /// both screens describe the same mapping.
    var action: String {
        switch self {
        case .left: "Next card"
        case .right: "Previous card"
        case .up: "Star or unstar"
        case .down: "Dismiss card"
        case .tap: "Flip card"
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

/// What the phone tells the Watch about the thing being controlled, so the
/// Watch can show what its next flick will act on.
struct PhoneContext: Codable, Sendable, Equatable {
    var title: String
    var index: Int
    var count: Int
    var isStarred: Bool
    var isFlipped: Bool

    static let empty = PhoneContext(title: "Deck empty", index: 0, count: 0,
                                    isStarred: false, isFlipped: false)
}
