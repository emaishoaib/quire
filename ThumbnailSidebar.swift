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
/// This is written in SwiftUI rather than wrapping PDFKit's `PDFThumbnailView` so that
/// each page can carry its own controls. What PDFKit gave for nothing is reproduced
/// here: the current page is highlighted, and the strip scrolls to keep it in view.
struct ThumbnailSidebar: View {
    @Bindable var document: QuireDocument
    let viewer: ViewerController
    let thumbnailWidth: Double

    @State private var thumbnails = ThumbnailCache()

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        if let page = document.pdf.page(at: index) {
                            cell(index: index, page: page)
                                .id(index)
                        }
                    }
                }
                .padding(.vertical, 14)
                .id(document.revision)
            }
            .onChange(of: viewer.currentPage) { _, page in
                withAnimation(.easeOut(duration: 0.2)) {
                    scroller.scrollTo(page, anchor: .center)
                }
            }
        }
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isCurrent = viewer.currentPage == index

        return VStack(spacing: 4) {
            Image(nsImage: thumbnails.image(for: page))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: thumbnailWidth, height: thumbnailWidth * 1.3)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
                )

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .contentShape(.rect)
        .onTapGesture { viewer.goToPage(index) }
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
