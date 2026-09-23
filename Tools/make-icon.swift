//
//  make-icon.swift
//  Quire
//
//  Draws the app icon and the PDF document icon.
//
//  The app icon is written into Assets.xcassets at every size Xcode asks for. The
//  document icon becomes DocumentIcon.icns, which Info.plist names as the icon for
//  PDFs, so files show Quire's own icon once it handles them.
//
//  Run from the repository root:
//      swift Tools/make-icon.swift
//

import AppKit

let master = 1024.0
let plate = CGRect(x: master * 0.05, y: master * 0.05, width: master * 0.9, height: master * 0.9)

func rgb(_ red: Double, _ green: Double, _ blue: Double) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

let scarlet = rgb(226, 54, 54)
let cherry = rgb(178, 28, 52)
let wine = rgb(120, 22, 48)
let banana = rgb(255, 214, 82)
let tangerine = rgb(255, 146, 44)
let slate = rgb(77, 87, 102)
let charcoal = rgb(33, 38, 46)
let cream = rgb(255, 248, 238)

/// Draws horizontal bars standing in for lines of text.
func lines(_ context: CGContext, in rect: CGRect, colour: CGColor, count: Int, thickness: Double, gap: Double, marginFraction: Double = 0.15) {
    context.setFillColor(colour)
    let margin = rect.width * marginFraction
    var y = rect.maxY - margin - thickness

    for index in 0..<count {
        let width = (rect.width - margin * 2) * (index == count - 1 ? 0.55 : 1)
        context.fill(CGRect(x: rect.minX + margin, y: y, width: width, height: thickness))
        y -= gap
    }
}

/// Draws the icon at 1024 points: a page of text under a magnifying glass.
///
/// Everything is clipped to the rounded square, so the glass handle can never spill
/// past the corner however the layout is nudged.
func drawIcon(in context: CGContext) {
    let scale = master / 512

    context.saveGState()
    context.addPath(CGPath(roundedRect: plate, cornerWidth: 112 * scale, cornerHeight: 112 * scale, transform: nil))
    context.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [scarlet, cherry, wine] as CFArray,
        locations: [0, 0.5, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: master),
        end: CGPoint(x: master, y: 0),
        options: []
    )

    let page = CGRect(x: 132 * scale, y: 142 * scale, width: 228 * scale, height: 292 * scale)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 20 * scale, color: CGColor(gray: 0, alpha: 0.32))
    context.setFillColor(cream)
    context.addPath(CGPath(roundedRect: page, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil))
    context.fillPath()
    context.restoreGState()

    lines(context, in: page, colour: slate, count: 6, thickness: 13 * scale, gap: 30 * scale)

    let glass = CGRect(x: 222 * scale, y: 128 * scale, width: 172 * scale, height: 172 * scale)
    context.setFillColor(cream)
    context.fillEllipse(in: glass)

    context.saveGState()
    context.addEllipse(in: glass.insetBy(dx: 10 * scale, dy: 10 * scale))
    context.clip()
    lines(
        context,
        in: glass.insetBy(dx: -20 * scale, dy: 10 * scale),
        colour: charcoal,
        count: 3,
        thickness: 22 * scale,
        gap: 46 * scale
    )
    context.restoreGState()

    let handleLength = 46 * scale
    context.setLineCap(.round)
    context.setStrokeColor(tangerine)
    context.setLineWidth(30 * scale)
    context.move(to: CGPoint(x: glass.maxX - 18 * scale, y: glass.minY + 20 * scale))
    context.addLine(to: CGPoint(x: glass.maxX - 18 * scale + handleLength, y: glass.minY + 20 * scale - handleLength))
    context.strokePath()

    context.setStrokeColor(banana)
    context.setLineWidth(28 * scale)
    context.strokeEllipse(in: glass)

    context.restoreGState()
}

/// A page of text under the magnifying glass, framed in red.
///
/// The frame and the band along the foot are one filled shape with the white page inset
/// inside it. Drawing them separately leaves a seam where the two edges fail to meet.
/// The gradient runs left to right across the page, so it is visible along the band and
/// the frame picks up the matching colour wherever it meets it.
func drawDocumentIcon(in context: CGContext) {
    let scale = master / 1024
    let outer = CGRect(x: 180 * scale, y: 90 * scale, width: 664 * scale, height: 844 * scale)
    let foldSize = 190 * scale
    let border = 22 * scale
    let bandHeight = 150 * scale

    func sheetPath(_ rect: CGRect, fold: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 26 * scale, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(sheetPath(outer, fold: foldSize))
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [scarlet, cherry, wine] as CFArray,
        locations: [0, 0.5, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: outer.minX, y: 0),
        end: CGPoint(x: outer.maxX, y: 0),
        options: []
    )
    context.restoreGState()

    let inner = outer.insetBy(dx: border, dy: border)
    let innerFold = foldSize - border
    let bandTop = outer.minY + bandHeight

    context.saveGState()
    context.addPath(sheetPath(inner, fold: innerFold))
    context.clip()
    context.clip(to: CGRect(x: 0, y: bandTop, width: master, height: master - bandTop))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: bandTop, width: master, height: master - bandTop))

    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: inner.maxX - innerFold, y: inner.maxY))
    corner.addLine(to: CGPoint(x: inner.maxX - innerFold, y: inner.maxY - innerFold))
    corner.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY - innerFold))
    corner.closeSubpath()
    context.setFillColor(rgb(240, 232, 233))
    context.addPath(corner)
    context.fillPath()

    context.setFillColor(slate)
    let margin = inner.width * 0.12
    var y = inner.maxY - 230 * scale
    for index in 0..<6 {
        let width = (inner.width - margin * 2) * (index == 5 ? 0.55 : 1)
        context.fill(CGRect(x: inner.minX + margin, y: y, width: width, height: 26 * scale))
        y -= 62 * scale
    }
    context.restoreGState()

    let glass = CGRect(x: 430 * scale, y: 180 * scale, width: 330 * scale, height: 330 * scale)
    let stroke = 46 * scale
    context.setFillColor(cream)
    context.fillEllipse(in: glass)

    context.saveGState()
    context.addEllipse(in: glass.insetBy(dx: stroke * 0.6, dy: stroke * 0.6))
    context.clip()
    lines(
        context,
        in: glass.insetBy(dx: -30 * scale, dy: 22 * scale),
        colour: charcoal,
        count: 3,
        thickness: 30 * scale,
        gap: 62 * scale,
        marginFraction: 0.14
    )
    context.restoreGState()

    let handleLength = 86 * scale
    context.setLineCap(.round)
    context.setStrokeColor(tangerine)
    context.setLineWidth(stroke)
    context.move(to: CGPoint(x: glass.maxX - stroke * 0.6, y: glass.minY + stroke * 0.7))
    context.addLine(to: CGPoint(x: glass.maxX - stroke * 0.6 + handleLength, y: glass.minY + stroke * 0.7 - handleLength))
    context.strokePath()

    context.setStrokeColor(banana)
    context.setLineWidth(stroke)
    context.strokeEllipse(in: glass)
}

func context(size: Int) -> CGContext {
    CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

let iconContext = context(size: Int(master))
drawIcon(in: iconContext)
let icon = iconContext.makeImage()!

let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
let folder = "Assets.xcassets/AppIcon.appiconset"
var images: [String] = []

for entry in entries {
    let pixels = entry.points * entry.scale
    let name = "icon_\(entry.points)x\(entry.points)\(entry.scale == 2 ? "@2x" : "").png"

    let output = context(size: pixels)
    output.interpolationQuality = .high
    output.draw(icon, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let representation = NSBitmapImageRep(cgImage: output.makeImage()!)
    try! representation.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(folder)/\(name)"))

    images.append("""
        {
          "filename" : "\(name)",
          "idiom" : "mac",
          "scale" : "\(entry.scale)x",
          "size" : "\(entry.points)x\(entry.points)"
        }
    """)
}

let documentContext = context(size: Int(master))
drawDocumentIcon(in: documentContext)
let documentIcon = documentContext.makeImage()!

let iconset = "DocumentIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for entry in entries {
    let pixels = entry.points * entry.scale
    let name = "icon_\(entry.points)x\(entry.points)\(entry.scale == 2 ? "@2x" : "").png"

    let output = context(size: pixels)
    output.interpolationQuality = .high
    output.draw(documentIcon, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let representation = NSBitmapImageRep(cgImage: output.makeImage()!)
    try! representation.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)
print("wrote DocumentIcon.icns")

let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try! contents.write(toFile: "\(folder)/Contents.json", atomically: true, encoding: .utf8)
print("wrote \(entries.count) sizes into \(folder)")
