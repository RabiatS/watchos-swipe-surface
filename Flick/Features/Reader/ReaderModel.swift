import Foundation
import Observation
import PDFKit
import SwiftUI

/// A block of reader content. Text documents are headings and paragraphs;
/// PDFs are pages. Both scroll in one column.
enum ReaderBlock: Identifiable {
    case heading(id: String, text: String, section: Int)
    case paragraph(id: String, text: String, section: Int)
    case page(id: String, index: Int, section: Int)

    var id: String {
        switch self {
        case .heading(let id, _, _), .paragraph(let id, _, _), .page(let id, _, _): id
        }
    }

    var section: Int {
        switch self {
        case .heading(_, _, let s), .paragraph(_, _, let s), .page(_, _, let s): s
        }
    }
}

/// What the view should do next. The model cannot reach the ScrollView, so
/// it posts a target and bumps a version; the view watches the version.
enum ScrollTarget: Equatable {
    case block(String)
    case y(CGFloat)
}

/// Recipes, scores, manuals: things read with the phone propped up and the
/// hands busy. Up and down move by most of a screen; left and right jump
/// between sections or pages.
@MainActor
@Observable
final class ReaderModel: ModeController {
    let mode = Mode.reader
    private let settings: AppSettings

    private(set) var title = "Nothing open"
    private(set) var blocks: [ReaderBlock] = []
    private(set) var sectionTitles: [String] = []
    private(set) var pages: PDFPages?
    private(set) var isSample = false

    /// Reported by the view as it scrolls.
    var offset: CGFloat = 0
    var viewportHeight: CGFloat = 1
    var contentHeight: CGFloat = 1
    var visibleBlockID: String?

    private(set) var scrollTarget: ScrollTarget?
    private(set) var scrollVersion = 0
    var showsControls = false

    private static let currentNameKey = "reader.currentName"

    init(settings: AppSettings) {
        self.settings = settings
        restore()
    }

    // MARK: Content

    var sectionCount: Int { sectionTitles.count }

    var currentSection: Int {
        guard let visibleBlockID, let block = blocks.first(where: { $0.id == visibleBlockID }) else { return 0 }
        return block.section
    }

    var progress: Double {
        guard contentHeight > viewportHeight else { return 1 }
        return min(1, max(0, (offset + viewportHeight) / contentHeight))
    }

    func load(url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let name = "current." + (ext.isEmpty ? "txt" : ext)
        let kept = try DocumentStore.keep(url, as: name, for: .reader)
        try open(kept, title: url.deletingPathExtension().lastPathComponent)
        settings.defaults.set(name, forKey: Self.currentNameKey)
        isSample = false
    }

    func paste(_ text: String, title: String = "Pasted text") throws {
        let kept = try DocumentStore.write(Data(text.utf8), as: "current.txt", for: .reader)
        try open(kept, title: title)
        settings.defaults.set("current.txt", forKey: Self.currentNameKey)
        isSample = false
    }

    func loadSample() {
        guard let url = SampleContent.recipeURL else { return }
        try? open(url, title: "Sample recipe")
        settings.defaults.removeObject(forKey: Self.currentNameKey)
        isSample = true
    }

    private func restore() {
        if let name = settings.defaults.string(forKey: Self.currentNameKey),
           let url = DocumentStore.url(name, for: .reader),
           (try? open(url, title: "Your document")) != nil {
            isSample = false
            return
        }
        loadSample()
    }

    private func open(_ url: URL, title: String) throws {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw ReaderError.unreadable }
            let pages = PDFPages(document: document)
            self.pages = pages
            blocks = (0..<pages.count).map { .page(id: "page-\($0)", index: $0, section: $0) }
            sectionTitles = (0..<pages.count).map { "Page \($0 + 1)" }
        } else {
            let text = try String(contentsOf: url, encoding: .utf8)
            pages = nil
            (blocks, sectionTitles) = Self.parse(text)
        }
        self.title = title
        offset = 0
        visibleBlockID = blocks.first?.id
        request(.y(0))
    }

    /// Markdown-ish: a line starting with `#` opens a section, blank lines
    /// separate paragraphs. Anything else is a paragraph.
    static func parse(_ text: String) -> ([ReaderBlock], [String]) {
        var blocks: [ReaderBlock] = []
        var titles: [String] = []
        var section = -1
        var paragraph: [String] = []
        var counter = 0

        func flush() {
            guard !paragraph.isEmpty else { return }
            if section < 0 { section = 0; titles.append("Start") }
            counter += 1
            blocks.append(.paragraph(id: "p-\(counter)", text: paragraph.joined(separator: " "), section: section))
            paragraph.removeAll()
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                flush()
                section += 1
                let heading = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                titles.append(heading)
                counter += 1
                blocks.append(.heading(id: "h-\(counter)", text: heading, section: section))
            } else if line.isEmpty {
                flush()
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return (blocks, titles)
    }

    // MARK: Control

    var context: PhoneContext {
        let subtitle: String
        if pages != nil {
            subtitle = "Page \(currentSection + 1) of \(sectionCount)"
        } else if sectionCount > 1 {
            subtitle = "\(sectionTitles[min(currentSection, sectionCount - 1)]) · \(Int(progress * 100))%"
        } else {
            subtitle = "\(Int(progress * 100))%"
        }
        let unit = pages != nil ? "page" : "section"
        return PhoneContext(
            mode: .reader, title: title, subtitle: subtitle, badge: nil,
            legend: PhoneContext.legend([
                (.up, "Scroll up"), (.down, "Scroll down"),
                (.left, "Next \(unit)"), (.right, "Previous \(unit)"),
                (.tap, showsControls ? "Hide controls" : "Controls"),
            ]))
    }

    func apply(_ direction: SwipeDirection) -> String {
        let step = viewportHeight * 0.85
        switch direction {
        case .up:
            request(.y(max(0, offset - step)))
            return "Scrolled up"
        case .down:
            request(.y(min(max(0, contentHeight - viewportHeight), offset + step)))
            return "Scrolled down"
        case .left:
            return jump(to: currentSection + 1) ? "Next section" : "Already at the end"
        case .right:
            return jump(to: currentSection - 1) ? "Previous section" : "Already at the start"
        case .tap:
            showsControls.toggle()
            return showsControls ? "Showed controls" : "Hid controls"
        }
    }

    func crown(_ delta: Double) {
        let y = min(max(0, contentHeight - viewportHeight), max(0, offset + delta * 60))
        request(.y(y))
    }

    private func jump(to section: Int) -> Bool {
        guard section >= 0, section < sectionCount,
              let block = blocks.first(where: { $0.section == section }) else { return false }
        request(.block(block.id))
        return true
    }

    private func request(_ target: ScrollTarget) {
        scrollTarget = target
        scrollVersion += 1
    }

    var textSize: Double { settings.readerTextSize }

    enum ReaderError: LocalizedError {
        case unreadable
        var errorDescription: String? { "That file could not be read." }
    }
}
