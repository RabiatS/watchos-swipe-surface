// Draws the bundled sample slide deck as a PDF: six slides with a title,
// a number and a distinct colour, so a deck can be driven before the user
// has imported one of their own.
// Run: swift scripts/make-samples.swift
import CoreGraphics
import CoreText
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent().deletingLastPathComponent()
let out = root.appendingPathComponent("Flick/Samples/SampleSlides.pdf")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
var box = CGRect(x: 0, y: 0, width: 1920, height: 1080)
let ctx = CGContext(out as CFURL, mediaBox: &box, nil)!

let titles = ["A watch you hold", "Five gestures", "The phone on the stand", "The television across the room",
              "The headset with no buttons", "What we measure next"]
let hues: [CGFloat] = [0.62, 0.08, 0.33, 0.55, 0.78, 0.12]

func color(_ h: CGFloat, _ s: CGFloat, _ b: CGFloat) -> CGColor {
    // Simple HSB to RGB.
    let c = b * s, x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1)), m = b - c
    let (r, g, bl): (CGFloat, CGFloat, CGFloat) = switch Int(h * 6) % 6 {
    case 0: (c, x, 0); case 1: (x, c, 0); case 2: (0, c, x); case 3: (0, x, c); case 4: (x, 0, c); default: (c, 0, x)
    }
    return CGColor(colorSpace: space, components: [r + m, g + m, bl + m, 1])!
}

for (i, title) in titles.enumerated() {
    ctx.beginPDFPage(nil)
    ctx.setFillColor(color(hues[i], 0.55, 0.55))
    ctx.fill(box)
    ctx.setFillColor(color(hues[i], 0.35, 0.85))
    ctx.fill(CGRect(x: 0, y: 0, width: 1920, height: 12))

    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 110, nil)
    let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: CGColor(colorSpace: space, components: [1, 1, 1, 1])!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: title, attributes: attrs as [NSAttributedString.Key: Any]))
    ctx.textPosition = CGPoint(x: 140, y: 480)
    CTLineDraw(line, ctx)

    let small = CTFontCreateWithName("HelveticaNeue" as CFString, 48, nil)
    let sattrs: [CFString: Any] = [kCTFontAttributeName: small, kCTForegroundColorAttributeName: CGColor(colorSpace: space, components: [1, 1, 1, 0.75])!]
    let sub = CTLineCreateWithAttributedString(NSAttributedString(string: "Sample deck  ·  \(i + 1) of \(titles.count)", attributes: sattrs as [NSAttributedString.Key: Any]))
    ctx.textPosition = CGPoint(x: 140, y: 140)
    CTLineDraw(sub, ctx)
    ctx.endPDFPage()
}
ctx.closePDF()
print("wrote \(out.path)")
