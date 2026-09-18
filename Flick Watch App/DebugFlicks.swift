import Foundation

#if DEBUG
/// Scripted input for the simulator, where nothing can touch the Watch.
///
///   SIMCTL_CHILD_FLICK_MODE=slides SIMCTL_CHILD_FLICK_SEND=left,left,up \
///     xcrun simctl launch --terminate-running-process <watch> com.rabiats.flick.watchkitapp
///
/// `simctl launch` forwards arguments to iOS apps but not to watchOS ones.
/// It does forward environment variables prefixed `SIMCTL_CHILD_`. Debug
/// builds only. See `GesturePadView.runScript` for the timing.
enum DebugFlicks {
    static var scripted: [SwipeDirection] {
        let list = argument("-flickSend") ?? ProcessInfo.processInfo.environment["FLICK_SEND"]
        return (list ?? "")
            .split(separator: ",")
            .compactMap { SwipeDirection(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
    }

    static var mode: Mode? {
        Mode(rawValue: argument("-flickMode") ?? ProcessInfo.processInfo.environment["FLICK_MODE"] ?? "")
    }

    private static func argument(_ flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
#endif
