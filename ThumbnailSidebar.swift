//
//  ThumbnailSidebar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A strip of page thumbnails beside the document in Read mode.
///
/// This is written in SwiftUI rather than wrapping PDFKit's `PDFThumbnailView` so that
/// each page can carry its own controls. What PDFKit gave for nothing is reproduced
/// here: the current page is highlighted, and the strip scrolls to keep it in view.
///
/// Hovering a page reveals rotate and delete beneath it, hovering the gap between two
/// pages reveals a plus that inserts there, and a page can be dragged to a new position.
/// Unlike the Pages grid there is no selection, so every control acts on the one page it
/// belongs to, and a drag moves that page alone.
struct ThumbnailSidebar: View {
    /// How the sidebar slides in and out.
    ///
    /// Attached to the container that holds the sidebar, not to a `withAnimation` around
    /// the toggle: the setting is `@AppStorage`, so the change arrives from UserDefaults
    /// outside whatever transaction set it, and an animation wrapped around the toggle is
    /// simply lost.
    static let animation = Animation.spring(duration: 0.3, bounce: 0.1)

    /// How the pages part to show where a dragged page will land.
    static let dropAnimation = Animation.spring(duration: 0.22, bounce: 0.15)

    /// How thumbnails follow the size slider.
    ///
    /// Keyed to the width rather than wrapped around the slider's change, because the
    /// size is `@AppStorage` and arrives from UserDefaults outside any transaction.
    static let sizeAnimation = Animation.easeOut(duration: 0.12)

    @Bindable var document: QuireDocument
    let viewer: ViewerController
    let thumbnailWidth: Double

    @State private var thumbnails = ThumbnailCache()
    @State private var hovered: Int?
    @State private var insertionPoint: Int?
    @State private var dragging: Int?
    @State private var dropTarget: Int?
    @State private var errorMessage: String?

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(Array(document.pages.enumerated()), id: \.element) { index, page in
                        cell(index: index, page: page)
                    }
                }
                .padding(.vertical, 14)
            }
            .onChange(of: viewer.currentPage) { _, index in
                guard document.pages.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    scroller.scrollTo(document.pages[index], anchor: .center)
                }
            }
        }
        .alert("Couldn't insert those pages", isPresented: showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isCurrent = viewer.currentPage == index

        let isSlot = dropTarget == index && dragging != index

        return VStack(spacing: 4) {
            Image(nsImage: thumbnails.image(for: page))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: thumbnailWidth, height: thumbnailWidth * 1.3)
                .animation(Self.sizeAnimation, value: thumbnailWidth)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
                )
                .opacity(dragging == index ? 0.4 : 1)
                .overlay(alignment: .bottom) {
                    pageControls(index: index)
                        .opacity(hovered == index ? 1 : 0)
                        .allowsHitTesting(hovered == index)
                        .animation(.easeOut(duration: 0.12), value: hovered == index)
                }

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .padding(.top, isSlot ? 26 : 0)
        .overlay(alignment: .top) {
            if isSlot {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: thumbnailWidth, height: 3)
                    .padding(.top, 11)
            }
        }
        .animation(Self.dropAnimation, value: isSlot)
        .contentShape(.rect)
        .onTapGesture { viewer.goToPage(index) }
        .onDrag {
            dragging = index
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: SidebarDropDelegate(
                target: index,
                dragging: $dragging,
                dropTarget: $dropTarget,
                move: move
            )
        )
        .onHover { inside in
            hovered = inside ? index : (hovered == index ? nil : hovered)
        }
        .overlay(alignment: .top) {
            if index == 0 {
                insertionZone(at: 0, edge: .top, besidePage: index)
            }
        }
        .overlay(alignment: .bottom) {
            insertionZone(at: index + 1, edge: .bottom, besidePage: index)
        }
    }

    /// The rotate and delete buttons that appear over a hovered page.
    private func pageControls(index: Int) -> some View {
        HStack(spacing: 2) {
            controlButton("Rotate Left", systemImage: "rotate.left") {
                document.rotatePages(IndexSet(integer: index), by: -90)
            }
            controlButton("Rotate Right", systemImage: "rotate.right") {
                document.rotatePages(IndexSet(integer: index), by: 90)
            }
            controlButton("Delete Page", systemImage: "trash") {
                document.deletePages(IndexSet(integer: index))
                hovered = nil
            }
            .disabled(document.pageCount == 1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .onHover { inside in
            if inside {
                hovered = index
            }
        }
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .frame(width: 24, height: 21)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// A plus in the gap above or below a page, which inserts pages at `index`.
    ///
    /// The button stays in the view tree and only fades, because removing it while the
    /// pointer is on it makes hover flip on and off and the plus disappear.
    private func insertionZone(at index: Int, edge: VerticalEdge, besidePage page: Int) -> some View {
        let isVisible = insertionPoint == index || hovered == page

        return Color.clear
            .frame(height: 19)
            .contentShape(.rect)
            .onHover { inside in
                insertionPoint = inside ? index : (insertionPoint == index ? nil : insertionPoint)
            }
            .dropDestination(for: URL.self) { urls, _ in
                insert(pdfs: urls, at: index)
            } isTargeted: { targeted in
                insertionPoint = targeted ? index : (insertionPoint == index ? nil : insertionPoint)
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
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
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
            .offset(y: edge == .top ? -10 : 10)
    }

    /// Moves the dragged page onto `target`, shifting that page aside.
    private func move(from source: Int, to target: Int) {
        guard source != target else { return }
        let destination = target > source ? target + 1 : target
        document.movePages(IndexSet(integer: source), to: destination)
    }

    /// Inserts dropped PDF files at `index`, refusing anything that is not a PDF.
    private func insert(pdfs urls: [URL], at index: Int) -> Bool {
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        guard !pdfs.isEmpty else { return false }

        var insertAt = index
        do {
            for url in pdfs {
                insertAt += try document.insertPages(from: url, at: insertAt)
            }
        } catch {
            errorMessage = "One of the PDFs could not be read. It may be damaged or password protected."
            return false
        }
        return true
    }

    /// Asks for PDFs and inserts their pages at `index`.
    private func insertPages(at index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.message = "Choose PDFs to insert"
        guard panel.runModal() == .OK else { return }

        _ = insert(pdfs: panel.urls, at: index)
        insertionPoint = nil
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    /// How wide the sidebar has to be to hold a thumbnail of this width.
    static func sidebarWidth(for thumbnailWidth: Double) -> Double {
        thumbnailWidth + 48
    }
}

/// Handles a page being dropped onto the thumbnail at `target`.
private struct SidebarDropDelegate: DropDelegate {
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
