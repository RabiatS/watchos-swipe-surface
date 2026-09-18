import Foundation

/// Where imported content lives: one folder per mode under Application
/// Support, so a deck or a photo set survives relaunch without touching the
/// user's own files again.
enum DocumentStore {
    static func folder(for mode: Mode) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(mode.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Copies a file the user picked into the mode's folder under a fixed
    /// name, replacing whatever was there. Handles security-scoped URLs from
    /// the document picker.
    @discardableResult
    static func keep(_ source: URL, as name: String, for mode: Mode) throws -> URL {
        let dest = folder(for: mode).appendingPathComponent(name)
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }

    static func write(_ data: Data, as name: String, for mode: Mode) throws -> URL {
        let dest = folder(for: mode).appendingPathComponent(name)
        try data.write(to: dest, options: .atomic)
        return dest
    }

    static func url(_ name: String, for mode: Mode) -> URL? {
        let url = folder(for: mode).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func remove(_ name: String, for mode: Mode) {
        try? FileManager.default.removeItem(at: folder(for: mode).appendingPathComponent(name))
    }

    static func clear(_ mode: Mode) {
        try? FileManager.default.removeItem(at: folder(for: mode))
    }
}
