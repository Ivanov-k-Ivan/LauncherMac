import AppKit
import CoreGraphics

let size = 1024
let side = CGFloat(size)
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create bitmap context")
}

let bounds = CGRect(x: 0, y: 0, width: side, height: side)
let squircle = CGPath(
    roundedRect: bounds.insetBy(dx: 10, dy: 10),
    cornerWidth: 228,
    cornerHeight: 228,
    transform: nil
)

context.saveGState()
context.addPath(squircle)
context.clip()

let colors = [
    NSColor(calibratedRed: 0.16, green: 0.30, blue: 0.96, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.63, green: 0.18, blue: 0.88, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor.white.withAlphaComponent(0.35).cgColor,
        NSColor.white.withAlphaComponent(0).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    highlight,
    startCenter: CGPoint(x: side * 0.3, y: side * 0.85),
    startRadius: 0,
    endCenter: CGPoint(x: side * 0.3, y: side * 0.85),
    endRadius: side * 0.75,
    options: []
)

let inset: CGFloat = 296
let gap: CGFloat = 64
let cell = (side - inset * 2 - gap) / 2

for row in 0 ..< 2 {
    for column in 0 ..< 2 {
        let x = inset + CGFloat(column) * (cell + gap)
        let y = inset + CGFloat(row) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        context.addPath(
            CGPath(
                roundedRect: rect,
                cornerWidth: cell * 0.27,
                cornerHeight: cell * 0.27,
                transform: nil
            )
        )
        context.setFillColor(NSColor.white.withAlphaComponent(0.93).cgColor)
        context.fillPath()
    }
}

context.restoreGState()

guard let image = context.makeImage() else { fatalError("Could not render image") }
let representation = NSBitmapImageRep(cgImage: image)
guard let png = representation.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
