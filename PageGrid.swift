//
//  PageGrid.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A grid of page thumbnails with Finder-style selection and drag-to-reorder.
///
/// Click selects one page, Cmd-click adds or removes one, Shift-click extends from
/// the last page clicked, and double-click opens that page in the viewer. Dragging a
/// page that is part of the selection moves the whole selection.
struct PageGrid: View {
    @Bindable var document: QuireDocument
    @Binding var selection: Set<Int>
    var onOpenPage: (Int) -> Void

    @Environment(\.undoManager) private var undoManager

    @State private var thumbnails = ThumbnailCache()
    @State private var anchor: Int?
    @State private var dragging: Int?
    @State private var dropTarget: Int?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    if let page = document.pdf.page(at: index) {
                        cell(index: index, page: page)
                    }
                }
            }
            .padding(24)
            .id(document.revision)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isSelected = selection.contains(index)
        let isDropTarget = dropTarget == index && dragging != index

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
                        .strokeBorder(
                            isDropTarget ? Color.accentColor : (isSelected ? Color.accentColor : .clear),
                            style: StrokeStyle(lineWidth: 2, dash: isDropTarget ? [5] : [])
                        )
                )

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(.rect)
        .onTapGesture(count: 2) { onOpenPage(index) }
        .simultaneousGesture(TapGesture().onEnded { click(index) })
        .onDrag {
            dragging = index
            if !selection.contains(index) {
                selection = [index]
                anchor = index
            }
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: PageDropDelegate(
                target: index,
                dragging: $dragging,
                dropTarget: $dropTarget,
                move: move
            )
        )
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

    /// Moves the dragged page, or the whole selection when the dragged page belongs to it.
    private func move(from source: Int, to target: Int) {
        let moving = selection.contains(source) ? IndexSet(selection) : IndexSet(integer: source)
        guard !moving.contains(target) else { return }

        let destination = target > source ? target + 1 : target
        document.movePages(moving, to: destination, undoManager: undoManager)

        let start = destination - moving.filter { $0 < destination }.count
        selection = Set(start..<start + moving.count)
        anchor = start
    }
}

/// Handles a page being dropped onto the cell at `target`.
private struct PageDropDelegate: DropDelegate {
    let target: Int
    @Binding var dragging: Int?
    @Binding var dropTarget: Int?
    let move: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        dropTarget = target
    }

    func dropExited(info: DropInfo) {
        if dropTarget == target {
            dropTarget = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dragging = nil
            dropTarget = nil
        }
        guard let source = dragging else { return false }
        move(source, target)
        return true
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
