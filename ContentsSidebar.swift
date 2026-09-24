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
    /// The sidebar's width on this tab.
    ///
    /// Fixed rather than following the thumbnail size, because titles need room that a
    /// small thumbnail setting would not leave them.
    static let width = 240.0

    let document: QuireDocument
    let viewer: ViewerController

    @State private var items: [OutlineItem] = []

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Table of Contents",
                    systemImage: "list.bullet.indent",
                    description: Text("This PDF doesn't list its sections.")
                )
            } else {
                List(items, children: \.children) { item in
                    Text(item.label)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                        .onTapGesture {
                            if let destination = item.destination {
                                viewer.go(to: destination)
                            }
                        }
                        .help(item.label)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .onChange(of: document.pdf, initial: true) {
            items = OutlineItem.roots(of: document.pdf)
        }
    }
}

/// One entry in the table of contents, with its children already read out of PDFKit.
///
/// `PDFOutline` hands out its children one index at a time, while `List` needs them as an
/// array, or nil for an entry with none so that it draws no disclosure triangle. The tree
/// is built once per document rather than on every redraw, so each entry keeps the same
/// identity and the list remembers which entries are expanded.
struct OutlineItem: Identifiable {
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

    private static func children(of outline: PDFOutline) -> [OutlineItem] {
        (0..<outline.numberOfChildren).compactMap { outline.child(at: $0) }.map(OutlineItem.init)
    }
}
