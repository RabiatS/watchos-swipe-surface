import Foundation
import Observation

/// One flick received, with when it landed and what it did.
struct ReceivedSwipe: Identifiable, Sendable {
    let event: SwipeEvent
    let receivedAt: Date
    let mode: Mode
    let action: String

    var id: UUID { event.id }

    /// Sender clock to receiver clock. Paired devices keep their clocks close,
    /// so this is a fair "how long did that take" figure, not a precise one.
    var latency: TimeInterval { receivedAt.timeIntervalSince(event.sentAt) }
}

/// Everything a flick touches, in one place. The link hands messages here,
/// the current mode changes, the log grows, and the Watch is told the new state.
@MainActor
@Observable
final class SwipeHub {
    let link = PhoneLink()
    let settings: AppSettings

    let reader: ReaderModel
    let photos: PhotosModel
    let slides: SlidesModel
    let prompter: PrompterModel

    private(set) var mode: Mode
    private(set) var received: [ReceivedSwipe] = []
    /// Increments per event. Views key animations to it.
    private(set) var pulse = 0

    private let maxLog = 300

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        reader = ReaderModel(settings: settings)
        photos = PhotosModel()
        slides = SlidesModel(defaults: settings.defaults)
        prompter = PrompterModel(settings: settings)
        mode = settings.lastMode

        link.onMessage = { [weak self] message in
            self?.handle(message) ?? .empty
        }
        link.onStateChange = { [weak self] in
            self?.publish()
        }
        publish()
    }

    var current: any ModeController {
        switch mode {
        case .reader: reader
        case .photos: photos
        case .slides: slides
        case .prompter: prompter
        }
    }

    /// The context as the Watch should see it, with the horizontal legend
    /// swapped when the user has reversed left and right.
    var context: PhoneContext {
        var context = current.context
        if settings.reverseHorizontal {
            let left = context.legend[SwipeDirection.left.rawValue]
            let right = context.legend[SwipeDirection.right.rawValue]
            context.legend[SwipeDirection.left.rawValue] = right
            context.legend[SwipeDirection.right.rawValue] = left
        }
        return context
    }

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        if mode == .prompter { prompter.pause() }
        if mode == .photos { photos.pausePlayback() }
        mode = newMode
        settings.lastMode = newMode
        publish()
    }

    @discardableResult
    func handle(_ message: WatchMessage) -> PhoneContext {
        switch message {
        case .swipe(let event):
            handle(event)
        case .crown(let delta):
            current.crown(delta)
            publish()
        case .setMode(let newMode):
            setMode(newMode)
        case .hello:
            break
        }
        return context
    }

    @discardableResult
    func handle(_ event: SwipeEvent) -> PhoneContext {
        let direction = settings.reverseHorizontal ? event.direction.mirroredHorizontally : event.direction
        let action = current.apply(direction)
        received.insert(ReceivedSwipe(event: event, receivedAt: .now, mode: mode, action: action), at: 0)
        if received.count > maxLog {
            received.removeLast(received.count - maxLog)
        }
        pulse += 1
        publish()
        return context
    }

    /// Modes call this when their content changes outside a flick, such as
    /// after an import, so the Watch follows.
    func contentChanged() {
        publish()
    }

    func clearLog() {
        received.removeAll()
    }

    var lastReceived: ReceivedSwipe? { received.first }

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
        link.publish(context)
    }
}
