import AppKit
import Observation
import PDFKit

@MainActor
@Observable
final class ThumbnailCache {
    private struct Key: Hashable {
        let page: ObjectIdentifier
        let rotation: Int
    }

    @ObservationIgnored private var images: [Key: NSImage] = [:]

    func image(for page: PDFPage) -> NSImage {
        let key = Key(page: ObjectIdentifier(page), rotation: page.rotation)
        if let image = images[key] {
            return image
        }
        let image = page.thumbnail(of: NSSize(width: 280, height: 360), for: .cropBox)
        images[key] = image
        return image
    }
}
