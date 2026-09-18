import Foundation
import Observation

/// One flick received, with when it landed, so latency can be shown.
struct ReceivedSwipe: Identifiable, Sendable {
    let event: SwipeEvent
    let receivedAt: Date

    var id: UUID { event.id }

    /// Sender clock to receiver clock. Paired devices keep their clocks close,
    /// so this is a fair "how long did that take" figure, not a precise one.
    var latency: TimeInterval { receivedAt.timeIntervalSince(event.sentAt) }
}

/// Everything a flick touches, in one place. The link hands events here,
/// the deck changes, the log grows, and the Watch is told the new state.
@MainActor
@Observable
final class SwipeHub {
    let link = PhoneLink()
    private(set) var deck = Deck.sample
    private(set) var received: [ReceivedSwipe] = []
    /// Increments per event. Views key animations to it.
    private(set) var pulse = 0

    private let maxLog = 300

    init() {
        link.onEvent = { [weak self] event in
            self?.handle(event) ?? .empty
        }
        link.onStateChange = { [weak self] in
            self?.publish()
        }
        publish()
    }

    @discardableResult
    func handle(_ event: SwipeEvent) -> PhoneContext {
        received.insert(ReceivedSwipe(event: event, receivedAt: .now), at: 0)
        if received.count > maxLog {
            received.removeLast(received.count - maxLog)
        }
        deck.apply(event.direction)
        pulse += 1
        publish()
        return deck.context
    }

    func undoDismiss() {
        deck.undoDismiss()
        publish()
    }

    func resetDeck() {
        deck = .sample
        publish()
    }

    func clearLog() {
        received.removeAll()
    }

    var lastDirection: SwipeDirection? { received.first?.event.direction }

    var watchEventCount: Int {
        received.count { $0.event.source == .watch }
    }

    /// Mean latency of Watch events, in seconds, or nil when there are none.
    var meanWatchLatency: TimeInterval? {
        let watch = received.filter { $0.event.source == .watch }
        guard !watch.isEmpty else { return nil }
        return watch.map(\.latency).reduce(0, +) / Double(watch.count)
    }

    private func publish() {
        link.publish(deck.context)
    }
}
