import Foundation
import UIKit

/// Bundled content so every mode does something on first launch, before the
/// user has imported anything of their own.
enum SampleContent {
    static var recipeURL: URL? { Bundle.main.url(forResource: "SampleRecipe", withExtension: "md") }
    static var scriptURL: URL? { Bundle.main.url(forResource: "SampleScript", withExtension: "txt") }
    static var slidesURL: URL? { Bundle.main.url(forResource: "SampleSlides", withExtension: "pdf") }

    /// Five generated photos. Drawn at runtime so nothing large ships in the
    /// bundle and the set is obviously a placeholder.
    @MainActor
    static func photos() -> [UIImage] {
        let names = ["Dawn", "Harbour", "Orchard", "Ridge", "Ember"]
        let hues: [CGFloat] = [0.08, 0.56, 0.30, 0.66, 0.98]
        return zip(names, hues).map { name, hue in
            let size = CGSize(width: 1200, height: 1600)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                let top = UIColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1)
                let bottom = UIColor(hue: hue, saturation: 0.75, brightness: 0.45, alpha: 1)
                let colors = [top.cgColor, bottom.cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .left
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .paragraphStyle: paragraph,
                ]
                name.draw(in: CGRect(x: 80, y: size.height - 260, width: size.width - 160, height: 160),
                          withAttributes: attributes)
                let small: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 44, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                ]
                "Sample photo".draw(at: CGPoint(x: 84, y: size.height - 120), withAttributes: small)
            }
        }
    }
}
