import Foundation

/// What the phone is showing, and therefore what the flicks mean.
enum Mode: String, Codable, Sendable, CaseIterable, Identifiable {
    case reader, photos, slides, prompter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reader: "Reader"
        case .photos: "Photos"
        case .slides: "Slides"
        case .prompter: "Prompter"
        }
    }

    var symbolName: String {
        switch self {
        case .reader: "book.pages"
        case .photos: "photo.on.rectangle.angled"
        case .slides: "rectangle.on.rectangle"
        case .prompter: "text.line.first.and.arrowtriangle.forward"
        }
    }

    /// One line for the mode picker.
    var blurb: String {
        switch self {
        case .reader: "Recipes, scores, manuals. Prop the phone up and turn pages from the wrist."
        case .photos: "Show a set of photos and videos with the phone across the table."
        case .slides: "Drive a PDF deck on the phone or a mirrored display."
        case .prompter: "Scrolling script for speaking or filming, paced from the wrist."
        }
    }
}

/// What the phone tells the Watch about the thing being controlled. The
/// legend is what makes the pad self-describing: each direction is labelled
/// with what it will do right now.
struct PhoneContext: Codable, Sendable, Equatable {
    var mode: Mode
    var title: String
    var subtitle: String
    /// An SF Symbol shown beside the title, such as a star or a play mark.
    var badge: String?
    /// Short labels keyed by `SwipeDirection.rawValue`. String keys so the
    /// JSON is a plain object on both ends.
    var legend: [String: String]

    func label(for direction: SwipeDirection) -> String? {
        legend[direction.rawValue]
    }

    static func legend(_ pairs: [(SwipeDirection, String)]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.rawValue, $1) })
    }

    static let empty = PhoneContext(mode: .reader, title: "Nothing open", subtitle: "",
                                    badge: nil, legend: [:])
}

/// Everything the Watch can send. Swipes are the point; the rest is the
/// plumbing a remote needs.
enum WatchMessage: Codable, Sendable {
    case swipe(SwipeEvent)
    /// Digital Crown rotation, in detents. Positive is toward the wearer.
    case crown(Double)
    case setMode(Mode)
    /// Asks for the current context, for when the pad has just opened.
    case hello
}
