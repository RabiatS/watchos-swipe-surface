import Foundation

#if DEBUG
/// Scripted flicks for the simulator, where nothing can swipe the Watch.
///
///   xcrun simctl launch <watch> com.rabiats.flick.watchkitapp -flickSend left,left,up,tap,right
///
/// Directions fire in order as soon as the phone is reachable. Debug builds
/// only. See `GesturePadView.runScriptedFlicks` for the timing.
enum DebugFlicks {
    static var scripted: [SwipeDirection] {
        parse(argument() ?? ProcessInfo.processInfo.environment["FLICK_SEND"])
    }

    /// `simctl launch` forwards arguments to iOS apps but not to watchOS ones.
    /// It does forward environment variables prefixed `SIMCTL_CHILD_`, so:
    ///
    ///   SIMCTL_CHILD_FLICK_SEND=left,up xcrun simctl launch <watch> com.rabiats.flick.watchkitapp
    private static func argument() -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-flickSend"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static func parse(_ list: String?) -> [SwipeDirection] {
        guard let list else { return [] }
        return list
            .split(separator: ",")
            .compactMap { SwipeDirection(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
    }
}
#endif
