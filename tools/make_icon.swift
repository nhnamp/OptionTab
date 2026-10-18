// Draws the OptionTab app icon and writes Resources/AppIcon.icns.
// Run from the project folder: swift tools/make_icon.swift
//
// The icon shows the switcher panel: three window titles, the middle one selected.
// The selected title ends with "…", because the panel truncates long titles at the end.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let accent = CGColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let dimWhite = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.45)

/// Draws the icon on a 1024 × 1024 grid. Origin is bottom left.
func drawIcon(in ctx: CGContext) {
    // Body with the macOS icon margin (100 px on each side), and a soft shadow below it.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Dark gradient, like the HUD panel of the switcher.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [CGColor(srgbRed: 0.20, green: 0.24, blue: 0.32, alpha: 1),
                                       CGColor(srgbRed: 0.07, green: 0.08, blue: 0.12, alpha: 1)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    func bar(x: CGFloat, centerY: CGFloat, width: CGFloat, color: CGColor) {
        let rect = CGRect(x: x, y: centerY - 22, width: width, height: 44)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
    }
    func ellipsis(x: CGFloat, centerY: CGFloat, color: CGColor) {
        ctx.setFillColor(color)
        for i in 0..<3 {
            ctx.fillEllipse(in: CGRect(x: x + CGFloat(i) * 44 - 13, y: centerY - 13, width: 26, height: 26))
        }
    }

    // Top title: short, not truncated.
    bar(x: 240, centerY: 702, width: 340, color: dimWhite)

    // Selected title: accent row, white title, truncated with "…".
    let row = CGRect(x: 190, y: 437, width: 644, height: 150)
    ctx.addPath(CGPath(roundedRect: row, cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.setFillColor(accent)
    ctx.fillPath()
    bar(x: 240, centerY: 512, width: 380, color: white)
    ellipsis(x: 670, centerY: 512, color: white)

    // Bottom title: shorter.
    bar(x: 240, centerY: 322, width: 260, color: dimWhite)
}

func writePNG(size: Int, to url: URL) throws {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: ctx)
    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "make_icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create \(url.path)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "make_icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot write \(url.path)"])
    }
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try writePNG(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try writePNG(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try writePNG(size: 1024, to: URL(fileURLWithPath: "docs/images/05_app_icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed with status \(iconutil.terminationStatus)") }
print("Wrote Resources/AppIcon.icns and docs/images/05_app_icon.png")
