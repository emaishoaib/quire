//
//  ThumbnailSidebar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// A strip of page thumbnails beside the document in Read mode.
///
/// PDFKit's own thumbnail view is used rather than the editing grid: it follows the
/// scroll position, highlights the current page and scrolls the document when a page
/// is clicked, all without being told. `attachCount` and `revision` are read so the
/// view is re-linked whenever the viewer is rebuilt or the pages change.
struct ThumbnailSidebar: NSViewRepresentable {
    let controller: ViewerController
    let attachCount: Int
    let revision: Int
    let thumbnailWidth: Double

    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnails = PDFThumbnailView()
        thumbnails.backgroundColor = .clear
        apply(to: thumbnails)
        thumbnails.pdfView = controller.attachedView
        return thumbnails
    }

    func updateNSView(_ thumbnails: PDFThumbnailView, context: Context) {
        if thumbnails.pdfView !== controller.attachedView {
            thumbnails.pdfView = controller.attachedView
        }
        apply(to: thumbnails)
    }

    /// Sizes the thumbnails. The sidebar is sized from these, so there is always one column.
    private func apply(to thumbnails: PDFThumbnailView) {
        let size = NSSize(width: thumbnailWidth, height: thumbnailWidth * 1.3)
        if thumbnails.thumbnailSize != size {
            thumbnails.thumbnailSize = size
        }
        thumbnails.maximumNumberOfColumns = 1
    }

    /// How wide the sidebar has to be to hold a thumbnail of this width.
    static func sidebarWidth(for thumbnailWidth: Double) -> Double {
        thumbnailWidth + 48
    }
}

/// The size slider under the thumbnails, in the manner of Finder's icon size control.
struct ThumbnailSizeControl: View {
    @Binding var thumbnailWidth: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.portrait")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            Slider(value: $thumbnailWidth, in: 60...220)
                .controlSize(.mini)

            Image(systemName: "rectangle.portrait")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
