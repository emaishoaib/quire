import CoreGraphics
import CoreText
import Foundation
import Vision

nonisolated enum OCREngine {

    struct Word {
        let text: String
        var spaceAfter: Bool
        let box: CGRect
    }

    static func searchablePage(from page: CGPDFPage, rotation: Int) async throws -> Data? {
        let mediaBox = page.getBoxRect(.mediaBox)
        guard let image = render(page, mediaBox: mediaBox) else { return nil }

        let words = try await recognizeWords(in: image, rotation: rotation)
        guard !words.isEmpty else { return nil }

        return writePage(page, mediaBox: mediaBox, rotation: rotation, words: words)
    }

    static func render(_ page: CGPDFPage, mediaBox: CGRect) -> CGImage? {
        let scale = min(300.0 / 72.0, 4000.0 / max(mediaBox.width, mediaBox.height))
        let width = Int(mediaBox.width * scale)
        let height = Int(mediaBox.height * scale)
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -mediaBox.minX, y: -mediaBox.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    static func recognizeWords(in image: CGImage, rotation: Int) async throws -> [Word] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = true
        request.minimumTextHeightFraction = 0

        let observations = try await request.perform(
            on: image,
            orientation: orientation(for: rotation)
        )

        return observations.flatMap { observation -> [Word] in
            guard let candidate = observation.topCandidates(1).first else { return [] }
            let text = candidate.string

            var words = wordRanges(in: text).compactMap { range -> Word? in
                guard let region = try? candidate.boundingBox(for: range) else { return nil }
                return Word(text: String(text[range]), spaceAfter: true, box: region.boundingBox.cgRect)
            }
            if words.isEmpty {
                return [Word(text: text, spaceAfter: false, box: observation.boundingBox.cgRect)]
            }
            words[words.count - 1].spaceAfter = false
            return words
        }
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?

        for index in text.indices {
            if text[index].isWhitespace {
                if let start {
                    ranges.append(start..<index)
                }
                start = nil
            } else if start == nil {
                start = index
            }
        }
        if let start {
            ranges.append(start..<text.endIndex)
        }
        return ranges
    }

    private static func orientation(for rotation: Int) -> CGImagePropertyOrientation {
        switch rotation {
        case 90: .right
        case 180: .down
        case 270: .left
        default: .up
        }
    }

    static func writePage(_ page: CGPDFPage, mediaBox: CGRect, rotation: Int, words: [Word]) -> Data? {
        let data = NSMutableData()
        var box = mediaBox
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }

        context.beginPage(mediaBox: &box)
        context.drawPDFPage(page)

        let upright = rotation % 180 == 0
            ? mediaBox.size
            : CGSize(width: mediaBox.height, height: mediaBox.width)

        context.saveGState()
        context.translateBy(x: mediaBox.minX, y: mediaBox.minY)
        context.concatenate(uprightToPage(rotation: rotation, pageSize: mediaBox.size))
        context.setTextDrawingMode(.invisible)

        for word in words {
            let rect = CGRect(
                x: word.box.minX * upright.width,
                y: word.box.minY * upright.height,
                width: word.box.width * upright.width,
                height: word.box.height * upright.height
            )
            draw(word.text, spaceAfter: word.spaceAfter, fittedTo: rect, in: context)
        }

        context.restoreGState()
        context.endPage()
        context.closePDF()
        return data as Data
    }

    private static func uprightToPage(rotation: Int, pageSize: CGSize) -> CGAffineTransform {
        let width = pageSize.width
        let height = pageSize.height

        switch rotation {
        case 90: return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: width, ty: 0)
        case 180: return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case 270: return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: height)
        default: return .identity
        }
    }

    private static func draw(_ text: String, spaceAfter: Bool, fittedTo rect: CGRect, in context: CGContext) {
        guard rect.width > 0, rect.height > 0 else { return }

        let font = CTFontCreateWithName("Helvetica" as CFString, rect.height * 0.8, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .init(kCTFontAttributeName as String): font
        ]

        let word = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let naturalWidth = CTLineGetTypographicBounds(word, nil, nil, nil)
        guard naturalWidth > 0 else { return }

        let line = spaceAfter
            ? CTLineCreateWithAttributedString(NSAttributedString(string: text + " ", attributes: attributes))
            : word

        context.textMatrix = CGAffineTransform(scaleX: rect.width / naturalWidth, y: 1)
        context.textPosition = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2)
        CTLineDraw(line, context)
    }
}
