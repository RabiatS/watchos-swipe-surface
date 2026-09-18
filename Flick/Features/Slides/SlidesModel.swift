import Foundation
import Observation
import PDFKit
import UIKit

/// A deck of slides on the phone, mirrored to a display or not. Left and
/// right move, and the rest are the presenter's three needs: a clock, a
/// blank screen, and a way to hide the presenter chrome.
@MainActor
@Observable
final class SlidesModel: ModeController {
    let mode = Mode.slides

    enum Source {
        case pdf(PDFPages)
        case images([UIImage])

        @MainActor
        var count: Int {
            switch self {
            case .pdf(let pages): pages.count
            case .images(let images): images.count
            }
        }
    }

    private(set) var title = "No deck"
    private(set) var source: Source?
    private(set) var index = 0
    private(set) var isSample = false

    private(set) var timerStartedAt: Date?
    private(set) var timerAccumulated: TimeInterval = 0
    private(set) var isBlanked = false
    var showsPresenterBar = true

    private var crownAccumulator = 0.0
    private let defaults: UserDefaults
    private static let currentNameKey = "slides.currentName"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    var count: Int { source?.count ?? 0 }

    var isTimerRunning: Bool { timerStartedAt != nil }

    func elapsed(at date: Date) -> TimeInterval {
        timerAccumulated + (timerStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    func image(width: CGFloat) -> UIImage? {
        switch source {
        case .pdf(let pages): pages.image(at: index, width: width)
        case .images(let images): images.indices.contains(index) ? images[index] : nil
        case nil: nil
        }
    }

    // MARK: Content

    func load(pdf url: URL) throws {
        let kept = try DocumentStore.keep(url, as: "current.pdf", for: .slides)
        try open(pdf: kept, title: url.deletingPathExtension().lastPathComponent)
        defaults.set("current.pdf", forKey: Self.currentNameKey)
        isSample = false
    }

    func load(images: [UIImage], title: String = "Chosen images") {
        guard !images.isEmpty else { return }
        source = .images(images)
        self.title = title
        index = 0
        isSample = false
        // Persist as JPEGs so the deck is still there tomorrow.
        DocumentStore.clear(.slides)
        for (i, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.85) {
                _ = try? DocumentStore.write(data, as: String(format: "img-%03d.jpg", i), for: .slides)
            }
        }
        defaults.set("images", forKey: Self.currentNameKey)
    }

    func loadSample() {
        guard let url = SampleContent.slidesURL else { return }
        try? open(pdf: url, title: "Sample deck")
        defaults.removeObject(forKey: Self.currentNameKey)
        isSample = true
    }

    private func restore() {
        let name = defaults.string(forKey: Self.currentNameKey)
        if name == "images" {
            let folder = DocumentStore.folder(for: .slides)
            let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
                .filter { $0.hasPrefix("img-") }.sorted()
            let images = files.compactMap { UIImage(contentsOfFile: folder.appendingPathComponent($0).path) }
            if !images.isEmpty {
                source = .images(images)
                title = "Chosen images"
                return
            }
        } else if let name, let url = DocumentStore.url(name, for: .slides),
                  (try? open(pdf: url, title: "Your deck")) != nil {
            return
        }
        loadSample()
    }

    private func open(pdf url: URL, title: String) throws {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else { throw SlidesError.unreadable }
        source = .pdf(PDFPages(document: document))
        self.title = title
        index = 0
        isBlanked = false
    }

    // MARK: Control

    var context: PhoneContext {
        PhoneContext(
            mode: .slides,
            title: title,
            subtitle: count > 0 ? "Slide \(index + 1) of \(count)" : "Import a PDF",
            badge: isBlanked ? "rectangle.slash" : (isTimerRunning ? "timer" : nil),
            legend: PhoneContext.legend([
                (.up, isTimerRunning ? "Pause timer" : "Start timer"),
                (.down, isBlanked ? "Unblank" : "Blank"),
                (.left, "Next"), (.right, "Previous"),
                (.tap, showsPresenterBar ? "Hide bar" : "Show bar"),
            ]))
    }

    func apply(_ direction: SwipeDirection) -> String {
        switch direction {
        case .left:
            return go(to: index + 1) ? "Next slide" : "Last slide"
        case .right:
            return go(to: index - 1) ? "Previous slide" : "First slide"
        case .up:
            toggleTimer()
            return isTimerRunning ? "Timer started" : "Timer paused"
        case .down:
            isBlanked.toggle()
            return isBlanked ? "Blanked" : "Unblanked"
        case .tap:
            showsPresenterBar.toggle()
            return showsPresenterBar ? "Showed bar" : "Hid bar"
        }
    }

    /// One slide per detent, in either direction.
    func crown(_ delta: Double) {
        crownAccumulator += delta
        while crownAccumulator >= 1 { crownAccumulator -= 1; _ = go(to: index + 1) }
        while crownAccumulator <= -1 { crownAccumulator += 1; _ = go(to: index - 1) }
    }

    func go(to newIndex: Int) -> Bool {
        guard newIndex >= 0, newIndex < count, newIndex != index else { return false }
        index = newIndex
        isBlanked = false
        return true
    }

    func toggleTimer() {
        if let start = timerStartedAt {
            timerAccumulated += Date.now.timeIntervalSince(start)
            timerStartedAt = nil
        } else {
            timerStartedAt = .now
        }
    }

    func resetTimer() {
        timerStartedAt = nil
        timerAccumulated = 0
    }

    enum SlidesError: LocalizedError {
        case unreadable
        var errorDescription: String? { "That PDF could not be opened." }
    }
}
