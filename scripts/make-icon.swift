// Draws the app icon for both targets: an indigo ground and a white flick,
// a short stroke that thickens toward its head, like a fast swipe leaves.
// Run: swift scripts/make-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

func render(_ path: String) {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Ground: a top-to-bottom indigo gradient, matching the Watch pad.
    let ground = CGGradient(colorsSpace: space,
                            colors: [rgb(0.31, 0.35, 0.90), rgb(0.12, 0.13, 0.42)] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    // The flick: a tapered stroke drawn as a filled shape, rising to the right.
    let start = CGPoint(x: size * 0.24, y: size * 0.36)
    let end = CGPoint(x: size * 0.70, y: size * 0.64)
    let tail = size * 0.035
    let head = size * 0.10
    let dx = end.x - start.x, dy = end.y - start.y
    let len = (dx * dx + dy * dy).squareRoot()
    let nx = -dy / len, ny = dx / len

    let flick = CGMutablePath()
    flick.move(to: CGPoint(x: start.x + nx * tail, y: start.y + ny * tail))
    flick.addLine(to: CGPoint(x: end.x + nx * head, y: end.y + ny * head))
    flick.addArc(center: end, radius: head, startAngle: atan2(ny, nx), endAngle: atan2(-ny, -nx), clockwise: true)
    flick.addLine(to: CGPoint(x: start.x - nx * tail, y: start.y - ny * tail))
    flick.addArc(center: start, radius: tail, startAngle: atan2(-ny, -nx), endAngle: atan2(ny, nx), clockwise: true)
    flick.closeSubpath()

    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.05, color: rgb(0, 0, 0, 0.30))
    ctx.setFillColor(rgb(1, 1, 1))
    ctx.addPath(flick)
    ctx.fillPath()

    // Two fading echoes behind the tail, the trail a flick leaves.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    for (i, alpha) in [0.45, 0.22].enumerated() {
        let offset = Double(i + 1) * size * 0.075
        let c = CGPoint(x: start.x - offset * dx / len, y: start.y - offset * dy / len)
        ctx.setFillColor(rgb(1, 1, 1, alpha))
        ctx.fillEllipse(in: CGRect(x: c.x - tail, y: c.y - tail, width: tail * 2, height: tail * 2))
    }

    let image = ctx.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(path)")
}

let root = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent().deletingLastPathComponent().path
render("\(root)/Flick/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
render("\(root)/Flick Watch App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
