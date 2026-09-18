import AVFoundation
import Foundation
import Observation
import UIKit

/// One picked photo or video, kept as a copy in the app's own folder.
struct MediaItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image(UIImage)
        case video(URL)
    }

    let id: UUID
    var kind: Kind
    var fileName: String
    var isStarred = false

    var isVideo: Bool {
        if case .video = kind { return true }
        return false
    }

    static func == (a: MediaItem, b: MediaItem) -> Bool {
        a.id == b.id && a.isStarred == b.isStarred
    }
}

/// A set of photos and videos shown one at a time, for the phone across the
/// table. Left and right move; up stars; down removes; tap plays a video or
/// toggles fill for a photo.
@MainActor
@Observable
final class PhotosModel: ModeController {
    let mode = Mode.photos

    private(set) var items: [MediaItem] = []
    private(set) var index = 0
    private(set) var isSample = false
    private(set) var fillsScreen = false
    private(set) var player: AVPlayer?
    private(set) var isPlaying = false

    private struct Record: Codable {
        var id: UUID
        var isVideo: Bool
        var fileName: String
        var isStarred: Bool
    }

    init() {
        restore()
    }

    var current: MediaItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    var count: Int { items.count }

    // MARK: Content

    /// Replaces the set. Images are stored as JPEG, videos are moved in.
    func replace(images: [UIImage], videos: [URL]) {
        pausePlayback()
        DocumentStore.clear(.photos)
        var new: [MediaItem] = []
        for image in images {
            let id = UUID()
            let name = "\(id.uuidString).jpg"
            if let data = image.jpegData(compressionQuality: 0.9),
               (try? DocumentStore.write(data, as: name, for: .photos)) != nil {
                new.append(MediaItem(id: id, kind: .image(image), fileName: name))
            }
        }
        for url in videos {
            let id = UUID()
            let name = "\(id.uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
            if let kept = try? DocumentStore.keep(url, as: name, for: .photos) {
                new.append(MediaItem(id: id, kind: .video(kept), fileName: name))
            }
        }
        guard !new.isEmpty else { return }
        items = new
        index = 0
        isSample = false
        fillsScreen = false
        saveIndex()
        preparePlayer()
    }

    func loadSample() {
        pausePlayback()
        items = SampleContent.photos().map { MediaItem(id: UUID(), kind: .image($0), fileName: "") }
        index = 0
        isSample = true
        preparePlayer()
    }

    private func restore() {
        guard let url = DocumentStore.url("index.json", for: .photos),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Record].self, from: data) else {
            loadSample()
            return
        }
        let folder = DocumentStore.folder(for: .photos)
        items = records.compactMap { record in
            let file = folder.appendingPathComponent(record.fileName)
            if record.isVideo {
                guard FileManager.default.fileExists(atPath: file.path) else { return nil }
                return MediaItem(id: record.id, kind: .video(file), fileName: record.fileName, isStarred: record.isStarred)
            }
            guard let image = UIImage(contentsOfFile: file.path) else { return nil }
            return MediaItem(id: record.id, kind: .image(image), fileName: record.fileName, isStarred: record.isStarred)
        }
        if items.isEmpty { loadSample() } else { preparePlayer() }
    }

    private func saveIndex() {
        guard !isSample else { return }
        let records = items.map { Record(id: $0.id, isVideo: $0.isVideo, fileName: $0.fileName, isStarred: $0.isStarred) }
        if let data = try? JSONEncoder().encode(records) {
            _ = try? DocumentStore.write(data, as: "index.json", for: .photos)
        }
    }

    // MARK: Control

    var context: PhoneContext {
        let tapLabel: String
        if let current, current.isVideo {
            tapLabel = isPlaying ? "Pause" : "Play"
        } else {
            tapLabel = fillsScreen ? "Fit" : "Fill"
        }
        return PhoneContext(
            mode: .photos,
            title: current.map { $0.isVideo ? "Video" : "Photo" } ?? "No photos",
            subtitle: count > 0 ? "\(index + 1) of \(count)" : "Choose some",
            badge: current?.isStarred == true ? "star.fill" : (isPlaying ? "play.fill" : nil),
            legend: PhoneContext.legend([
                (.up, current?.isStarred == true ? "Unstar" : "Star"),
                (.down, "Remove"),
                (.left, "Next"), (.right, "Previous"),
                (.tap, tapLabel),
            ]))
    }

    func apply(_ direction: SwipeDirection) -> String {
        switch direction {
        case .left:
            return go(to: index + 1) ? "Next" : "Last one"
        case .right:
            return go(to: index - 1) ? "Previous" : "First one"
        case .up:
            guard items.indices.contains(index) else { return "Nothing to star" }
            items[index].isStarred.toggle()
            saveIndex()
            return items[index].isStarred ? "Starred" : "Unstarred"
        case .down:
            guard items.indices.contains(index) else { return "Nothing to remove" }
            pausePlayback()
            let removed = items.remove(at: index)
            if !removed.fileName.isEmpty { DocumentStore.remove(removed.fileName, for: .photos) }
            if index >= items.count { index = max(0, items.count - 1) }
            saveIndex()
            preparePlayer()
            return "Removed"
        case .tap:
            if let current, current.isVideo {
                togglePlayback()
                return isPlaying ? "Playing" : "Paused"
            }
            fillsScreen.toggle()
            return fillsScreen ? "Filled" : "Fitted"
        }
    }

    func crown(_ delta: Double) {
        guard let player, current?.isVideo == true else { return }
        let time = player.currentTime().seconds + delta * 2
        player.seek(to: CMTime(seconds: max(0, time), preferredTimescale: 600))
    }

    func go(to newIndex: Int) -> Bool {
        guard newIndex >= 0, newIndex < items.count, newIndex != index else { return false }
        pausePlayback()
        index = newIndex
        fillsScreen = false
        preparePlayer()
        return true
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    private func preparePlayer() {
        if let current, case .video(let url) = current.kind {
            player = AVPlayer(url: url)
        } else {
            player = nil
        }
        isPlaying = false
    }
}
