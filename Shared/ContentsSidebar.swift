import PDFKit
import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case thumbnails = "Thumbnails"
    case contents = "Contents"

    var id: Self { self }

    static func opening(_ pdf: PDFDocument) -> SidebarTab {
        OutlineItem.roots(of: pdf).isEmpty ? .thumbnails : .contents
    }
}

struct ContentsSidebar: View {
    let model: PDFModel
    let viewer: ViewerController
    var didOpenPage: () -> Void = {}

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
        .onChange(of: model.pdf, initial: true) {
            items = OutlineItem.roots(of: model.pdf)
            entries = OutlineItem.flattened(items)
        }
    }

    private var current: OutlineItem.Entry? {
        let pageIndex = Dictionary(
            uniqueKeysWithValues: model.pages.enumerated().map { (ObjectIdentifier($0.element), $0.offset) }
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
            didOpenPage()
        }
    }

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

struct OutlineItem: Identifiable {
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

    var destination: PDFDestination? {
        outline.destination ?? (outline.action as? PDFActionGoTo)?.destination
    }

    init(_ outline: PDFOutline) {
        self.outline = outline
        let children = Self.children(of: outline)
        self.children = children.isEmpty ? nil : children
    }

    static func roots(of pdf: PDFDocument) -> [OutlineItem] {
        pdf.outlineRoot.map(children(of:)) ?? []
    }

    static func flattened(_ items: [OutlineItem], inside ancestors: [ObjectIdentifier] = []) -> [Entry] {
        items.flatMap { item in
            [Entry(item: item, ancestors: ancestors)]
                + flattened(item.children ?? [], inside: ancestors + [item.id])
        }
    }

    /// The entries under an outline, with any entry labelled only by its list number left out and its own entries taking its place.
    private static func children(of outline: PDFOutline) -> [OutlineItem] {
        (0..<outline.numberOfChildren).compactMap { outline.child(at: $0) }.flatMap { child in
            isListMarker(child.label) ? children(of: child) : [OutlineItem(child)]
        }
    }

    /// Whether a label is nothing but a clause number such as "1", "1.1" or "(a)", which Word leaves behind when a numbered heading's text is missing.
    static func isListMarker(_ label: String?) -> Bool {
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return label.wholeMatch(of: /\d+(\.\d+)*\.?|\((\d+|[a-zA-Z]{1,4})\)/) != nil
    }
}
