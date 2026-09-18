import Foundation

/// One thing the Watch can drive. Each mode owns its content and decides
/// what the five gestures and the crown mean while it is showing.
@MainActor
protocol ModeController: AnyObject {
    var mode: Mode { get }
    var context: PhoneContext { get }
    /// Returns a short description of what happened, for the log.
    @discardableResult
    func apply(_ direction: SwipeDirection) -> String
    /// Crown rotation in detents. Default: nothing.
    func crown(_ delta: Double)
}

extension ModeController {
    func crown(_ delta: Double) {}
}
