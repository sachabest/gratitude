import AppKit
import CoreGraphics

let width = 1200
let height = 630

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Warm cream-to-amber background, matching the app's SmileTint amber.
let bgColors = [
    CGColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1),
    CGColor(red: 0.99, green: 0.90, blue: 0.72, alpha: 1),
]
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: height),
    end: CGPoint(x: width, y: 0),
    options: []
)

// Smiling face, drawn as the SF Symbol used in the app itself (face.smiling.inverse).
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 300, weight: .regular)
if let symbol = NSImage(systemSymbolName: "face.smiling.inverse", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let tintedSymbol = NSImage(size: symbol.size)
    tintedSymbol.lockFocus()
    NSColor(calibratedRed: 0.91, green: 0.65, blue: 0.16, alpha: 1).set()
    let imageRect = NSRect(origin: .zero, size: symbol.size)
    imageRect.fill()
    symbol.draw(in: imageRect, from: .zero, operation: .destinationIn, fraction: 1)
    tintedSymbol.unlockFocus()

    let symbolSize = tintedSymbol.size
    let symbolRect = CGRect(
        x: (CGFloat(width) - symbolSize.width) / 2,
        y: CGFloat(height) / 2 - symbolSize.height / 2 + 40,
        width: symbolSize.width,
        height: symbolSize.height
    )
    if let cgSymbol = tintedSymbol.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        ctx.draw(cgSymbol, in: symbolRect)
    }
}

// "Gratitude" wordmark underneath.
let title = "Gratitude"
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 64, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.08, alpha: 1),
]
let attrString = NSAttributedString(string: title, attributes: attrs)
let textSize = attrString.size()
let textRect = CGRect(
    x: (CGFloat(width) - textSize.width) / 2,
    y: 90,
    width: textSize.width,
    height: textSize.height
)
attrString.draw(in: textRect)

NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
let outputPath = CommandLine.arguments[1]
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath), \(pngData.count) bytes")
