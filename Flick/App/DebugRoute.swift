import Foundation

#if DEBUG
/// Simulator-only routing, because `simctl` cannot tap.
///
///   xcrun simctl launch <phone> com.rabiats.flick -flickTab log
enum DebugRoute {
    enum Tab: String { case deck, log }

    static var initialTab: Tab {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-flickTab"), i + 1 < args.count,
              let tab = Tab(rawValue: args[i + 1]) else { return .deck }
        return tab
    }
}
#endif
