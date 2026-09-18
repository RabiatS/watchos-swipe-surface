import Foundation

/// How things are packed for WatchConnectivity. Messages carry raw JSON data;
/// the dictionary forms exist because `transferUserInfo` and
/// `updateApplicationContext` only accept property lists.
enum Wire {
    static let swipeKey = "swipe"
    static let contextKey = "context"

    static func encode(_ event: SwipeEvent) -> Data? {
        try? encoder().encode(event)
    }

    static func encode(_ context: PhoneContext) -> Data? {
        try? encoder().encode(context)
    }

    static func decodeEvent(_ data: Data) -> SwipeEvent? {
        try? decoder().decode(SwipeEvent.self, from: data)
    }

    static func decodeContext(_ data: Data) -> PhoneContext? {
        try? decoder().decode(PhoneContext.self, from: data)
    }

    static func userInfo(for event: SwipeEvent) -> [String: Any] {
        [swipeKey: encode(event) ?? Data()]
    }

    static func applicationContext(for context: PhoneContext) -> [String: Any] {
        [contextKey: encode(context) ?? Data()]
    }

    static func event(from dictionary: [String: Any]) -> SwipeEvent? {
        guard let data = dictionary[swipeKey] as? Data else { return nil }
        return decodeEvent(data)
    }

    static func context(from dictionary: [String: Any]) -> PhoneContext? {
        guard let data = dictionary[contextKey] as? Data else { return nil }
        return decodeContext(data)
    }

    // Seconds since 1970 keeps sub-millisecond precision on `sentAt`, which the
    // ISO 8601 strategy would round away. A fresh coder per call because
    // JSONEncoder is not Sendable and this is called from the session queue.
    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
}
