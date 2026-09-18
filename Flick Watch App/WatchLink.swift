import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// The Watch's end of the link. Sends flicks, crown turns and mode changes,
/// listens for what the phone is showing, and keeps a few counters the pad
/// can display.
///
/// WCSession calls its delegate on a private queue, so every delegate method
/// is `nonisolated`, reads what it needs from the session, and hops to the
/// main actor with plain values.
@MainActor
@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    private(set) var isActivated = false
    private(set) var isReachable = false
    private(set) var phoneContext: PhoneContext?
    private(set) var sentCount = 0
    private(set) var queuedCount = 0
    private(set) var failedCount = 0
    /// Round trip for the last acknowledged message, in seconds.
    private(set) var lastRoundTrip: TimeInterval?
    private(set) var lastError: String?

    private var pendingCrown = 0.0
    private var crownFlush: Task<Void, Never>?

    override init() {
        super.init()
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: Sending

    /// Sends a flick. Reachable means the phone app can be woken to receive it
    /// right now, and we get an acknowledgement back with the phone's new state.
    /// Otherwise the event is queued and delivered when the phone is next seen.
    func send(_ event: SwipeEvent) {
        send(.swipe(event), sentAt: event.sentAt, queueIfUnreachable: true)
    }

    func setMode(_ mode: Mode) {
        send(.setMode(mode), sentAt: .now, queueIfUnreachable: true)
    }

    /// Crown turns arrive many times a second. They are summed and sent at
    /// most every 80 ms, without waiting for a reply.
    func crown(_ delta: Double) {
        pendingCrown += delta
        guard crownFlush == nil else { return }
        crownFlush = Task {
            try? await Task.sleep(for: .milliseconds(80))
            let total = pendingCrown
            pendingCrown = 0
            crownFlush = nil
            guard abs(total) > 0.01, let data = Wire.encode(.crown(total)) else { return }
            WCSession.default.sendMessageData(data, replyHandler: nil) { error in
                let message = error.localizedDescription
                Task { @MainActor in self.lastError = message }
            }
        }
    }

    /// Asks the phone for its current state, for when the pad has just opened.
    func hello() {
        send(.hello, sentAt: .now, queueIfUnreachable: false)
    }

    private func send(_ message: WatchMessage, sentAt: Date, queueIfUnreachable: Bool) {
        guard let data = Wire.encode(message) else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessageData(data, replyHandler: { reply in
                let roundTrip = Date.now.timeIntervalSince(sentAt)
                let context = Wire.decodeContext(reply)
                Task { @MainActor in
                    self.lastRoundTrip = roundTrip
                    self.lastError = nil
                    if let context { self.phoneContext = context }
                }
            }, errorHandler: { error in
                let message = error.localizedDescription
                Task { @MainActor in
                    self.failedCount += 1
                    self.lastError = message
                }
            })
            sentCount += 1
        } else if queueIfUnreachable {
            session.transferUserInfo(Wire.userInfo(for: message))
            queuedCount += 1
        }
    }

    func haptic(for direction: SwipeDirection) {
        let type: WKHapticType = switch direction {
        case .up: .directionUp
        case .down: .directionDown
        case .left: .navigationLeftTurn
        case .right: .navigationRightTurn
        case .tap: .click
        }
        WKInterfaceDevice.current().play(type)
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let activated = activationState == .activated
        let reachable = session.isReachable
        let message = error?.localizedDescription
        let context = Wire.context(from: session.receivedApplicationContext)
        Task { @MainActor in
            self.isActivated = activated
            self.isReachable = reachable
            self.lastError = message
            if let context { self.phoneContext = context }
            if reachable { self.hello() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable { self.hello() }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let context = Wire.context(from: applicationContext) else { return }
        Task { @MainActor in
            self.phoneContext = context
        }
    }
}
