#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Observation
import PDFKit

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

@MainActor
@Observable
final class ThumbnailCache {
    private struct Key: Hashable {
        let page: ObjectIdentifier
        let rotation: Int
    }

    @ObservationIgnored private var images: [Key: PlatformImage] = [:]

    func image(for page: PDFPage) -> PlatformImage {
        let key = Key(page: ObjectIdentifier(page), rotation: page.rotation)
        if let image = images[key] {
            return image
        }
        let image = page.thumbnail(of: CGSize(width: 280, height: 360), for: .cropBox)
        images[key] = image
        return image
    }
}
