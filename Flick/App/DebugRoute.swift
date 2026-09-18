import Foundation

#if DEBUG
/// Simulator-only routing, because `simctl` cannot tap.
///
///   xcrun simctl launch <phone> com.rabiats.flick -flickTab log -flickMode slides
///
/// Any -flick argument also skips the welcome sheet.
enum DebugRoute {
    enum Tab: String { case stage, log, settings }

    static var initialTab: Tab {
        Tab(rawValue: value(for: "-flickTab") ?? "") ?? .stage
    }

    static var initialMode: Mode? {
        Mode(rawValue: value(for: "-flickMode") ?? "")
    }

    /// Any -flick argument other than -flickReset skips the welcome sheet.
    static var skipsOnboarding: Bool {
        CommandLine.arguments.contains { $0.hasPrefix("-flick") && $0 != "-flickReset" }
    }

    /// `-flickReset` wipes the app's defaults and imported files before
    /// launch, for a first-run capture. Preferences are cached by the system,
    /// so deleting the plist from outside does not do it.
    static func resetIfAsked() {
        guard CommandLine.arguments.contains("-flickReset"),
              let bundle = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundle)
        for mode in Mode.allCases { DocumentStore.clear(mode) }
    }

    private static func value(for flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
#endif
