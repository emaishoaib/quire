import AppKit

let master = 1024.0

func rgb(_ red: Double, _ green: Double, _ blue: Double) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

let wine = rgb(59, 15, 32)
let fold = rgb(92, 38, 58)
let cream = rgb(247, 239, 226)
let highlight = rgb(255, 240, 122)

func drawQ(in context: CGContext) {
    let lineHeight = 46.0
    let tail: [(top: Double, start: Double, width: Double)] = [
        (641, 550, 210), (717, 600, 240), (793, 650, 270)
    ]

    context.saveGState()
    context.addEllipse(in: CGRect(x: 130, y: 185, width: 640, height: 640))
    context.clip()
    context.setFillColor(cream)
    for top in stride(from: 185.0, through: 565, by: 76) {
        context.fill(CGRect(x: 130, y: top, width: 640, height: lineHeight))
    }
    for line in tail {
        context.fill(CGRect(x: 130, y: line.top, width: line.start - 130, height: lineHeight))
    }
    context.restoreGState()

    context.setFillColor(highlight)
    for line in tail {
        context.fill(CGRect(x: line.start, y: line.top, width: line.width, height: lineHeight))
    }
}

func drawDocumentIcon(in context: CGContext) {
    let sheet = CGRect(x: 180, y: 90, width: 664, height: 844)
    let foldSize = 190.0

    let path = CGMutablePath()
    path.move(to: CGPoint(x: sheet.minX, y: sheet.minY))
    path.addLine(to: CGPoint(x: sheet.maxX, y: sheet.minY))
    path.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY - foldSize))
    path.addLine(to: CGPoint(x: sheet.maxX - foldSize, y: sheet.maxY))
    path.addLine(to: CGPoint(x: sheet.minX, y: sheet.maxY))
    path.closeSubpath()
    context.setFillColor(wine)
    context.addPath(path)
    context.fillPath()

    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: sheet.maxX - foldSize, y: sheet.maxY))
    corner.addLine(to: CGPoint(x: sheet.maxX - foldSize, y: sheet.maxY - foldSize))
    corner.addLine(to: CGPoint(x: sheet.maxX, y: sheet.maxY - foldSize))
    corner.closeSubpath()
    context.setFillColor(fold)
    context.addPath(corner)
    context.fillPath()

    context.saveGState()
    context.translateBy(x: 512, y: 430)
    context.scaleBy(x: 0.72, y: -0.72)
    context.translateBy(x: -525, y: -505)
    drawQ(in: context)
    context.restoreGState()
}

func context(size: Int) -> CGContext {
    CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

let documentContext = context(size: Int(master))
drawDocumentIcon(in: documentContext)
let documentIcon = documentContext.makeImage()!

let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
let iconset = "macOS/DocumentIcon.iconset"
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
print("wrote macOS/DocumentIcon.icns")
