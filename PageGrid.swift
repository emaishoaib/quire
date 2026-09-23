//
//  PageGrid.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// A grid of page thumbnails with Finder-style selection.
///
/// Click selects one page, Cmd-click adds or removes one, Shift-click extends from
/// the last page clicked, and double-click opens that page in the viewer.
struct PageGrid: View {
    let pdf: PDFDocument
    @Binding var selection: Set<Int>
    var onOpenPage: (Int) -> Void

    @State private var thumbnails = ThumbnailCache()
    @State private var anchor: Int?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(0..<pdf.pageCount, id: \.self) { index in
                    if let page = pdf.page(at: index) {
                        cell(index: index, page: page)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isSelected = selection.contains(index)

        return VStack(spacing: 6) {
            Image(nsImage: thumbnails.image(for: page))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 180)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                )

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(.rect)
        .onTapGesture(count: 2) { onOpenPage(index) }
        .simultaneousGesture(TapGesture().onEnded { click(index) })
    }

    private func click(_ index: Int) {
        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            if selection.contains(index) {
                selection.remove(index)
            } else {
                selection.insert(index)
            }
            anchor = index
        } else if modifiers.contains(.shift), let anchor {
            selection = Set(min(anchor, index)...max(anchor, index))
        } else {
            selection = [index]
            anchor = index
        }
    }
}

/// Keeps rendered thumbnails until their page or its rotation changes.
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
