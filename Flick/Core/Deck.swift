import Foundation
import SwiftUI

/// Something on the phone for the Watch to push around. A deck of cards is the
/// simplest thing that has a next, a previous, a select, and a dismiss.
struct Card: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var hue: Double

    init(_ title: String, _ note: String, hue: Double) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.hue = hue
    }

    var color: Color {
        Color(hue: hue, saturation: 0.62, brightness: 0.86)
    }
}

struct Deck: Sendable {
    struct Dismissal: Sendable {
        let card: Card
        let index: Int
    }

    var cards: [Card]
    var index = 0
    var isFlipped = false
    var starred: Set<UUID> = []
    var dismissals: [Dismissal] = []
    /// The direction of the last move, so the view can animate the right way.
    var lastMove: SwipeDirection?
    /// Set when a move could not go anywhere, so the view can nudge instead.
    var bounced = false

    var current: Card? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    var isCurrentStarred: Bool {
        current.map { starred.contains($0.id) } ?? false
    }

    var context: PhoneContext {
        PhoneContext(title: current?.title ?? "Deck empty",
                     index: cards.isEmpty ? 0 : index + 1,
                     count: cards.count,
                     isStarred: isCurrentStarred,
                     isFlipped: isFlipped)
    }

    mutating func apply(_ direction: SwipeDirection) {
        lastMove = direction
        bounced = false
        switch direction {
        case .left:
            if index < cards.count - 1 {
                index += 1
                isFlipped = false
            } else {
                bounced = true
            }
        case .right:
            if index > 0 {
                index -= 1
                isFlipped = false
            } else {
                bounced = true
            }
        case .up:
            guard let card = current else { bounced = true; return }
            if starred.contains(card.id) {
                starred.remove(card.id)
            } else {
                starred.insert(card.id)
            }
        case .down:
            guard let card = current else { bounced = true; return }
            dismissals.append(Dismissal(card: card, index: index))
            cards.remove(at: index)
            if index >= cards.count {
                index = max(0, cards.count - 1)
            }
            isFlipped = false
        case .tap:
            guard current != nil else { bounced = true; return }
            isFlipped.toggle()
        }
    }

    mutating func undoDismiss() {
        guard let last = dismissals.popLast() else { return }
        let at = min(last.index, cards.count)
        cards.insert(last.card, at: at)
        index = at
        isFlipped = false
        lastMove = nil
    }

    static let sample = Deck(cards: [
        Card("Tangerine", "A flick to the left moves on. Right comes back.", hue: 0.07),
        Card("Sea", "Tap the Watch to turn a card over.", hue: 0.55),
        Card("Moss", "Flick up to star a card. Flick up again to unstar.", hue: 0.33),
        Card("Plum", "Flick down to dismiss. Undo lives on the phone.", hue: 0.80),
        Card("Honey", "The Watch shows the card it is pointing at.", hue: 0.12),
        Card("Slate", "Swipe the card on the phone too. Same pipeline.", hue: 0.60),
        Card("Coral", "The log tab shows every flick and its latency.", hue: 0.98),
        Card("Ink", "Last card. A flick left just nudges.", hue: 0.68),
    ])
}
