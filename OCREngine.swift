//
//  OCREngine.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import CoreGraphics
import CoreText
import Foundation
import Vision

/// Makes a scanned page searchable.
///
/// The page is rendered to an image, Vision reads the words from it, and a new page is
/// written with the original content plus an invisible text layer on top. Readers see the
/// scan unchanged, while search and text selection find the recognised words.
///
/// Nothing here touches PDFKit or the UI, so it runs off the main actor.
nonisolated enum OCREngine {

    /// A recognised word and where it sits, in the page as a reader sees it.
    ///
    /// `box` is normalised (0...1) against the upright page. `spaceAfter` is true for
    /// every word but the last on its line, and means a real space is drawn after it.
    struct Word {
        let text: String
        var spaceAfter: Bool
        let box: CGRect
    }

    /// Returns a one-page PDF with a text layer, or nil when no text was found.
    static func searchablePage(from page: CGPDFPage, rotation: Int) async throws -> Data? {
        let mediaBox = page.getBoxRect(.mediaBox)
        guard let image = render(page, mediaBox: mediaBox) else { return nil }

        let words = try await recognizeWords(in: image, rotation: rotation)
        guard !words.isEmpty else { return nil }

        return writePage(page, mediaBox: mediaBox, rotation: rotation, words: words)
    }

    /// Draws the page into a bitmap at 300 dpi, capped at 4000 pixels on the long side.
    ///
    /// `drawPDFPage` ignores the page's rotation, so this is always the unrotated page.
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

    /// Reads the image with Vision, one entry per word.
    ///
    /// Words are kept apart rather than merged into lines because a line of our font is
    /// a different width from the scanned line, which drags later words out of place.
    ///
    /// `minimumTextHeightFraction` is set to zero deliberately. Its default skips text
    /// below a fraction of the image height, which loses table and footnote text: on the
    /// sample scan it dropped a quarter of the lines, and misread "5GB" as "SGB".
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

    /// How the stored page has to be turned to be read upright.
    private static func orientation(for rotation: Int) -> CGImagePropertyOrientation {
        switch rotation {
        case 90: .right
        case 180: .down
        case 270: .left
        default: .up
        }
    }

    /// Writes a one-page PDF holding the original page plus the invisible text layer.
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

    /// Maps a point in the upright page onto the unrotated page, undoing PDF's clockwise rotation.
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

    /// Draws one word stretched to cover `rect`, so highlights land on the scanned word.
    ///
    /// The trailing space is drawn outside that fitted width and spills into the gap,
    /// which is what stops PDFKit from running neighbouring words together.
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
