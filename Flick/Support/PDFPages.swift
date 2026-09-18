import PDFKit
import UIKit

/// Renders PDF pages to images on demand and keeps them. Rendering is quick
/// enough on the main actor for the page in view and its neighbours; the
/// cache means each page is drawn once per size.
@MainActor
final class PDFPages {
    let document: PDFDocument
    private var cache: [Int: UIImage] = [:]
    private var renderedWidth: CGFloat = 0

    init(document: PDFDocument) {
        self.document = document
    }

    var count: Int { document.pageCount }

    func image(at index: Int, width: CGFloat) -> UIImage? {
        let width = max(320, width)
        if abs(width - renderedWidth) > 1 {
            cache.removeAll()
            renderedWidth = width
        }
        if let cached = cache[index] { return cached }
        guard let page = document.page(at: index) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0 else { return nil }
        let scale = UIScreen.main.scale
        let size = CGSize(width: width * scale, height: bounds.height / bounds.width * width * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        cache[index] = image
        return image
    }

    /// Height of a page when laid out at the given width, for placeholders.
    func aspectRatio(at index: Int) -> CGFloat {
        guard let page = document.page(at: index) else { return 1.4 }
        let b = page.bounds(for: .mediaBox)
        return b.width > 0 ? b.height / b.width : 1.4
    }
}
