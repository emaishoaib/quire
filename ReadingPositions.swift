//
//  ReadingPositions.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/10/26.
//

import PDFKit

/// A spot in a PDF: a page, and the point on it that sits at the top left of the view.
///
/// The point is in the page's own coordinates, which is how PDFKit describes a place to
/// scroll to, so it means the same spot at any zoom and in any size of window.
struct ReadingPosition {
    let page: Int
    let x: Double
    let y: Double
}

extension ReadingPosition {

    /// Reads the position out of a place PDFKit reports the view as showing.
    ///
    /// There is none when the page is no longer part of a document, which is the case
    /// for a page that has since been deleted.
    init?(_ destination: PDFDestination) {
        guard let page = destination.page, let document = page.document else { return nil }
        self.init(page: document.index(for: page), x: destination.point.x, y: destination.point.y)
    }

    /// The same spot as a place PDFKit can scroll to.
    ///
    /// There is none when the PDF no longer has that many pages, which is the case for
    /// a file that has been replaced by a shorter one since.
    func destination(in document: PDFDocument) -> PDFDestination? {
        guard let page = document.page(at: page) else { return nil }
        return PDFDestination(page: page, at: CGPoint(x: x, y: y))
    }
}

/// Where each PDF was last scrolled to, kept in the app's preferences.
///
/// Positions are filed under the PDF's path, so a file that is moved or renamed is
/// treated as one never opened before. Nothing is written to the PDF itself.
enum ReadingPositions {
    private static let key = "readingPositions"

    static func save(_ position: ReadingPosition, for url: URL) {
        var positions = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        positions[name(of: url)] = [
            "page": Double(position.page),
            "x": position.x,
            "y": position.y,
        ]
        UserDefaults.standard.set(positions, forKey: key)
    }

    static func position(for url: URL) -> ReadingPosition? {
        let positions = UserDefaults.standard.dictionary(forKey: key)
        guard let saved = positions?[name(of: url)] as? [String: Double],
              let page = saved["page"], let x = saved["x"], let y = saved["y"]
        else { return nil }
        return ReadingPosition(page: Int(page), x: x, y: y)
    }

    /// The path a PDF's position is filed under, the same whichever link it was opened through.
    private static func name(of url: URL) -> String {
        url.resolvingSymlinksInPath().path
    }
}
