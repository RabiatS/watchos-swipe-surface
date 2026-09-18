import Foundation
import Observation

/// User-facing settings, backed by UserDefaults. One object, observed by the
/// views that care, written through on every change.
@MainActor
@Observable
final class AppSettings {
    /// Shared with the mode models so everything the app remembers lives in
    /// one suite, and tests can hand in an empty one.
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keepAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? true
        reverseHorizontal = defaults.bool(forKey: Key.reverseHorizontal)
        readerTextSize = defaults.object(forKey: Key.readerTextSize) as? Double ?? 22
        prompterTextSize = defaults.object(forKey: Key.prompterTextSize) as? Double ?? 34
        prompterMirror = defaults.bool(forKey: Key.prompterMirror)
        hasOnboarded = defaults.bool(forKey: Key.hasOnboarded)
        lastMode = Mode(rawValue: defaults.string(forKey: Key.lastMode) ?? "") ?? .reader
    }

    /// A propped-up phone must not go dark mid-recipe.
    var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: Key.keepAwake) } }
    /// Some people think of a left flick as "pull the previous one in".
    var reverseHorizontal: Bool { didSet { defaults.set(reverseHorizontal, forKey: Key.reverseHorizontal) } }
    var readerTextSize: Double { didSet { defaults.set(readerTextSize, forKey: Key.readerTextSize) } }
    var prompterTextSize: Double { didSet { defaults.set(prompterTextSize, forKey: Key.prompterTextSize) } }
    /// Flipped for a beam-splitter prompter glass.
    var prompterMirror: Bool { didSet { defaults.set(prompterMirror, forKey: Key.prompterMirror) } }
    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Key.hasOnboarded) } }
    var lastMode: Mode { didSet { defaults.set(lastMode.rawValue, forKey: Key.lastMode) } }

    private enum Key {
        static let keepAwake = "settings.keepAwake"
        static let reverseHorizontal = "settings.reverseHorizontal"
        static let readerTextSize = "settings.readerTextSize"
        static let prompterTextSize = "settings.prompterTextSize"
        static let prompterMirror = "settings.prompterMirror"
        static let hasOnboarded = "settings.hasOnboarded"
        static let lastMode = "settings.lastMode"
    }
}
