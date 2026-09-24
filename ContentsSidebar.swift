//
//  ContentsSidebar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import PDFKit
import SwiftUI

/// Which list the sidebar beside the document is showing.
enum SidebarTab: String, CaseIterable, Identifiable {
    case thumbnails = "Thumbnails"
    case contents = "Contents"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .thumbnails: "rectangle.portrait.on.rectangle.portrait"
        case .contents: "list.bullet.indent"
        }
    }
}

/// The document's table of contents, in the sidebar beside the document in Read mode.
///
/// The entries come from the PDF's outline, which is the list of sections a PDF can carry
/// for readers to show. Scans and many generated PDFs have none, and get an empty state.
struct ContentsSidebar: View {
    let document: QuireDocument
    let viewer: ViewerController

    @State private var items: [OutlineItem] = []
    @State private var entries: [OutlineItem.Entry] = []
    @State private var expanded = Set<ObjectIdentifier>()

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Table of Contents",
                    systemImage: "list.bullet.indent",
                    description: Text("This PDF doesn't list its sections.")
                )
            } else {
                ScrollViewReader { scroller in
                    List {
                        ForEach(items) { item in
                            OutlineRow(item: item, currentID: current?.item.id, expanded: $expanded, open: open)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .onChange(of: current?.item.id, initial: true) {
                        revealCurrent(with: scroller)
                    }
                }
            }
        }
        .onChange(of: document.pdf, initial: true) {
            items = OutlineItem.roots(of: document.pdf)
            entries = OutlineItem.flattened(items)
        }
    }

    /// The section being read: the last entry, in reading order, starting on or before the current page.
    ///
    /// Entries are compared by page, because that is as finely as PDFKit reports where the
    /// reader is, so of several sections starting on the current page, the last one wins.
    /// An entry whose page has been deleted never matches, because its page is no longer
    /// among the document's pages.
    private var current: OutlineItem.Entry? {
        let pageIndex = Dictionary(
            uniqueKeysWithValues: document.pages.enumerated().map { (ObjectIdentifier($0.element), $0.offset) }
        )
        return entries.last { entry in
            guard let page = entry.item.destination?.page,
                  let index = pageIndex[ObjectIdentifier(page)]
            else { return false }
            return index <= viewer.currentPage
        }
    }

    private func open(_ item: OutlineItem) {
        if let destination = item.destination {
            viewer.go(to: destination)
        }
    }

    /// Expands the sections around the current entry and scrolls it into view.
    ///
    /// The scroll waits a moment, because the rows of a section that has only just been
    /// expanded do not exist yet to scroll to. A section the reader collapses stays
    /// collapsed until reading moves on to another entry.
    private func revealCurrent(with scroller: ScrollViewProxy) {
        guard let current else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            expanded.formUnion(current.ancestors)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeOut(duration: 0.2)) {
                scroller.scrollTo(current.item.id)
            }
        }
    }
}

/// One entry in the table of contents, with its sections nested beneath it.
///
/// Built from disclosure groups rather than the list's own `children:` form, because
/// that form keeps its expansion to itself, and the sidebar needs to open the section
/// being read. The expansion lives in `expanded` instead.
///
/// The current section is drawn in the accent colour, echoing the outline the thumbnail
/// strip draws around the current page.
private struct OutlineRow: View {
    let item: OutlineItem
    let currentID: ObjectIdentifier?
    @Binding var expanded: Set<ObjectIdentifier>
    let open: (OutlineItem) -> Void

    var body: some View {
        if let children = item.children {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    OutlineRow(item: child, currentID: currentID, expanded: $expanded, open: open)
                }
            } label: {
                title
            }
        } else {
            title
        }
    }

    private var title: some View {
        let isCurrent = item.id == currentID

        return Text(item.label)
            .lineLimit(2)
            .fontWeight(isCurrent ? .semibold : .regular)
            .foregroundStyle(isCurrent ? Color.accentColor : .primary)
            .animation(.easeOut(duration: 0.2), value: isCurrent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { open(item) }
            .help(item.label)
    }

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expanded.contains(item.id) },
            set: { isExpanded in
                if isExpanded {
                    expanded.insert(item.id)
                } else {
                    expanded.remove(item.id)
                }
            }
        )
    }
}

/// One entry in the table of contents, with its children already read out of PDFKit.
///
/// `PDFOutline` hands out its children one index at a time, while the list needs them as
/// an array, or nil for an entry with none so that it draws no disclosure triangle. The
/// tree is built once per document rather than on every redraw, so each entry keeps the
/// same identity and stays expanded or collapsed as it was.
struct OutlineItem: Identifiable {
    /// An entry together with the entries it sits inside, outermost first.
    struct Entry {
        let item: OutlineItem
        let ancestors: [ObjectIdentifier]
    }

    let outline: PDFOutline
    let children: [OutlineItem]?

    var id: ObjectIdentifier { ObjectIdentifier(outline) }

    var label: String {
        outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Where the entry leads.
    ///
    /// A PDF can store this either as the entry's destination or as a go-to action
    /// carrying one, and both are common, so both are read.
    var destination: PDFDestination? {
        outline.destination ?? (outline.action as? PDFActionGoTo)?.destination
    }

    init(_ outline: PDFOutline) {
        self.outline = outline
        let children = Self.children(of: outline)
        self.children = children.isEmpty ? nil : children
    }

    /// The top-level entries, which are the children of the outline's invisible root.
    static func roots(of pdf: PDFDocument) -> [OutlineItem] {
        pdf.outlineRoot.map(children(of:)) ?? []
    }

    /// Every entry in reading order, each with the entries it sits inside.
    static func flattened(_ items: [OutlineItem], inside ancestors: [ObjectIdentifier] = []) -> [Entry] {
        items.flatMap { item in
            [Entry(item: item, ancestors: ancestors)]
                + flattened(item.children ?? [], inside: ancestors + [item.id])
        }
    }

    private static func children(of outline: PDFOutline) -> [OutlineItem] {
        (0..<outline.numberOfChildren).compactMap { outline.child(at: $0) }.map(OutlineItem.init)
    }
}
