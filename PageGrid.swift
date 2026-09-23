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
///
/// Editing is done in place: hovering a page reveals rotate and delete buttons beneath
/// it, and hovering the gap between two pages reveals a plus that inserts there.
struct PageGrid: View {
    @Bindable var document: QuireDocument
    @Binding var selection: Set<Int>
    var onOpenPage: (Int) -> Void

    @Environment(\.undoManager) private var undoManager

    @State private var thumbnails = ThumbnailCache()
    @State private var anchor: Int?
    @State private var dragging: Int?
    @State private var dropTarget: Int?
    @State private var hovered: Int?
    @State private var insertionPoint: Int?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 210), spacing: 28)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    if let page = document.pdf.page(at: index) {
                        cell(index: index, page: page)
                    }
                }
            }
            .padding(32)
            .id(document.revision)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand {
            guard !selection.isEmpty else { return }
            delete(IndexSet(selection))
        }
        .onCommand(#selector(NSResponder.selectAll(_:))) {
            selection = Set(0..<document.pageCount)
        }
        .alert("Couldn't insert those pages", isPresented: showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isSelected = selection.contains(index)
        let isDropTarget = dropTarget == index && dragging != index

        return VStack(spacing: 6) {
            thumbnail(index: index, page: page, isSelected: isSelected, isDropTarget: isDropTarget)

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(.rect)
        .onTapGesture(count: 2) { onOpenPage(index) }
        .simultaneousGesture(TapGesture().onEnded { click(index) })
        .onHover { inside in
            hovered = inside ? index : (hovered == index ? nil : hovered)
        }
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
        .overlay(alignment: .leading) {
            if index == 0 {
                insertionZone(at: 0, edge: .leading, besidePage: index)
            }
        }
        .overlay(alignment: .trailing) {
            insertionZone(at: index + 1, edge: .trailing, besidePage: index)
        }
    }

    private func thumbnail(index: Int, page: PDFPage, isSelected: Bool, isDropTarget: Bool) -> some View {
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
            .overlay(alignment: .bottom) {
                let isVisible = hovered == index && dragging == nil
                pageControls(index: index)
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(isVisible)
                    .animation(.easeOut(duration: 0.12), value: isVisible)
            }
    }

    /// The rotate and delete buttons that float beneath a hovered page.
    private func pageControls(index: Int) -> some View {
        HStack(spacing: 2) {
            controlButton("Rotate Left", systemImage: "rotate.left") {
                document.rotatePages(IndexSet(integer: index), by: -90, undoManager: undoManager)
            }
            controlButton("Rotate Right", systemImage: "rotate.right") {
                document.rotatePages(IndexSet(integer: index), by: 90, undoManager: undoManager)
            }
            controlButton("Delete Page", systemImage: "trash") {
                delete(IndexSet(integer: index))
            }
            .disabled(document.pageCount == 1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .offset(y: 6)
        .onHover { inside in
            if inside {
                hovered = index
            }
        }
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .frame(width: 22, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// A plus in the gap beside a page that inserts pages at `index`.
    ///
    /// The button is always present and only fades, because removing it from the view
    /// tree while the pointer is on it makes hover flip on and off and the plus vanish.
    /// It stays visible while the pointer is over `besidePage`, the gap, or the plus itself.
    private func insertionZone(at index: Int, edge: HorizontalEdge, besidePage page: Int) -> some View {
        let isVisible = (insertionPoint == index || hovered == page) && dragging == nil

        return Color.clear
            .frame(width: 28)
            .contentShape(.rect)
            .onHover { inside in
                insertionPoint = inside ? index : (insertionPoint == index ? nil : insertionPoint)
            }
            .overlay {
                Button {
                    insertPages(at: index)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.regularMaterial, in: .circle)
                        .overlay(Circle().strokeBorder(.separator))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help(index == 0 ? "Insert pages before this page" : "Insert pages here")
                .opacity(isVisible ? 1 : 0)
                .allowsHitTesting(isVisible)
                .onHover { inside in
                    if inside {
                        insertionPoint = index
                    }
                }
                .animation(.easeOut(duration: 0.12), value: isVisible)
            }
            .offset(x: edge == .leading ? -14 : 14)
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

    private func delete(_ indices: IndexSet) {
        document.deletePages(indices, undoManager: undoManager)
        selection = []
        hovered = nil
    }

    /// Asks for PDFs and inserts their pages at `index`.
    private func insertPages(at index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Choose PDFs to insert"
        guard panel.runModal() == .OK else { return }

        var insertAt = index
        do {
            for url in panel.urls {
                insertAt += try document.insertPages(from: url, at: insertAt, undoManager: undoManager)
            }
        } catch {
            errorMessage = "One of the PDFs could not be read. It may be damaged or password protected."
        }
        insertionPoint = nil
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
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
