import PDFKit

struct ReadingPosition: Codable {
    let page: Int
    let x: Double
    let y: Double
    let scale: Double?
}

extension ReadingPosition {
    init?(_ destination: PDFDestination, scale: Double?) {
        guard let page = destination.page, let document = page.document else { return nil }
        self.init(
            page: document.index(for: page),
            x: destination.point.x,
            y: destination.point.y,
            scale: scale
        )
    }

    func destination(in document: PDFDocument) -> PDFDestination? {
        guard let page = document.page(at: page) else { return nil }
        return PDFDestination(page: page, at: CGPoint(x: x, y: y))
    }
}

enum ReadingPositions {
    private static let attribute = "com.mashoaib.quire.position"

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

    static func removeOldList() {
        UserDefaults.standard.removeObject(forKey: oldKey)
    }
}
