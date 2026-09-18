import Foundation
import Observation
import WatchConnectivity

/// The phone's end of the link. Receives flicks from the Watch, answers each
/// one with the phone's new state, and pushes that state again whenever the
/// deck changes so the Watch always knows what it is pointing at.
///
/// WCSession calls its delegate on a private queue, so every delegate method
/// is `nonisolated`, converts what it received into plain values, and hops to
/// the main actor.
@MainActor
@Observable
final class PhoneLink: NSObject, WCSessionDelegate {
    struct State: Sendable, Equatable {
        var isActivated = false
        var isPaired = false
        var isWatchAppInstalled = false
        var isReachable = false
    }

    private(set) var state = State()
    private(set) var lastError: String?

    /// Called on the main actor for every event that arrives. Returns the
    /// context to acknowledge with, so the Watch sees the result of its flick.
    @ObservationIgnored var onEvent: ((SwipeEvent) -> PhoneContext)?
    /// Called on the main actor when pairing or reachability changes.
    @ObservationIgnored var onStateChange: (() -> Void)?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    var isSupported: Bool { WCSession.isSupported() }

    /// Application context is "latest value wins" and survives the Watch app
    /// being closed, which is exactly right for "what is the phone showing".
    func publish(_ context: PhoneContext) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(Wire.applicationContext(for: context))
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Main-actor handling

    private func deliver(_ event: SwipeEvent) -> PhoneContext {
        onEvent?(event) ?? .empty
    }

    private func apply(_ newState: State, error: String? = nil) {
        let changed = newState != state
        state = newState
        if let error { lastError = error }
        if changed { onStateChange?() }
    }

    private nonisolated static func snapshot(_ session: WCSession) -> State {
        State(isActivated: session.activationState == .activated,
              isPaired: session.isPaired,
              isWatchAppInstalled: session.isWatchAppInstalled,
              isReachable: session.isReachable)
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let snapshot = Self.snapshot(session)
        let message = error?.localizedDescription
        Task { @MainActor in
            self.apply(snapshot, error: message)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let snapshot = Self.snapshot(session)
        Task { @MainActor in self.apply(snapshot) }
    }

    /// Happens when the user switches to a different Watch. Re-activating
    /// picks up the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let snapshot = Self.snapshot(session)
        Task { @MainActor in self.apply(snapshot) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let snapshot = Self.snapshot(session)
        Task { @MainActor in self.apply(snapshot) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard let event = Wire.decodeEvent(messageData) else { return }
        Task { @MainActor in
            _ = self.deliver(event)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        guard let event = Wire.decodeEvent(messageData) else {
            replyHandler(Data())
            return
        }
        // The SDK does not mark reply blocks Sendable. It is only ever called
        // once, from this Task, so carrying it across is safe.
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            let context = self.deliver(event)
            reply(Wire.encode(context) ?? Data())
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let event = Wire.event(from: userInfo) else { return }
        Task { @MainActor in
            _ = self.deliver(event)
        }
    }
}
