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
///
/// The zoom is only there when the user chose one. A PDF left at the fit it opened
/// with has none, and is fitted afresh to whatever size the window is next time.
struct ReadingPosition: Codable {
    let page: Int
    let x: Double
    let y: Double
    let scale: Double?
}

extension ReadingPosition {

    /// Reads the position out of a place PDFKit reports the view as showing.
    ///
    /// There is none when the page is no longer part of a document, which is the case
    /// for a page that has since been deleted.
    init?(_ destination: PDFDestination, scale: Double?) {
        guard let page = destination.page, let document = page.document else { return nil }
        self.init(
            page: document.index(for: page),
            x: destination.point.x,
            y: destination.point.y,
            scale: scale
        )
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

/// Where each PDF was last scrolled to, kept on the PDF's own file.
///
/// The position is an extended attribute, a small labelled note macOS keeps beside a
/// file's contents rather than inside them. It therefore follows the file when it is
/// moved or renamed, and a different PDF put at the same path has none. The contents
/// of the PDF are never written to, so other readers see no change.
///
/// A PDF that cannot be written to keeps no position, and opens on its first page.
enum ReadingPositions {
    private static let attribute = "com.mashoaib.quire.position"

    /// Where positions were kept before, as a list in the app's preferences.
    private static let oldKey = "readingPositions"

    static func save(_ position: ReadingPosition, for url: URL) {
        guard let data = try? JSONEncoder().encode(position) else { return }
        url.withUnsafeFileSystemRepresentation { path in
            _ = data.withUnsafeBytes { setxattr(path, attribute, $0.baseAddress, $0.count, 0, 0) }
        }
    }

    static func position(for url: URL) -> ReadingPosition? {
        url.withUnsafeFileSystemRepresentation { path in
            let size = getxattr(path, attribute, nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { getxattr(path, attribute, $0.baseAddress, size, 0, 0) }
            guard read == size else { return nil }
            return try? JSONDecoder().decode(ReadingPosition.self, from: data)
        }
    }

    /// Deletes the list of positions that used to be kept in the app's preferences.
    ///
    /// The positions in it are not carried over, so a PDF last closed under the old
    /// scheme opens on its first page once.
    static func removeOldList() {
        UserDefaults.standard.removeObject(forKey: oldKey)
    }
}
