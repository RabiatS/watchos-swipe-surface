import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// The Watch's end of the link. Sends flicks, listens for what the phone is
/// showing, and keeps a few counters the pad can display.
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

    override init() {
        super.init()
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a flick. Reachable means the phone app can be woken to receive it
    /// right now, and we get an acknowledgement back with the phone's new state.
    /// Otherwise the event is queued and delivered when the phone is next seen.
    func send(_ event: SwipeEvent) {
        guard let data = Wire.encode(event) else { return }
        let session = WCSession.default
        let sentAt = event.sentAt

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
        } else {
            session.transferUserInfo(Wire.userInfo(for: event))
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
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
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
