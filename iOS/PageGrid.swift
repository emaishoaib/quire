import PDFKit
import SwiftUI

struct PageGrid: View {
    let model: PDFModel
    let currentPage: Int
    let openPage: (Int) -> Void

    @State private var thumbnails = ThumbnailCache()
    @State private var selection = Set<Int>()
    @State private var dropTarget: Int?
    @State private var insertionPoint = 0
    @State private var isInserting = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompact ? 156 : 170, maximum: 210), spacing: isCompact ? 16 : 28)]
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(Array(model.pages.enumerated()), id: \.element) { index, page in
                        cell(index: index, page: page)
                    }
                }
                .padding(isCompact ? 16 : 32)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture { selection = [] }
            }
            .onAppear {
                guard model.pages.indices.contains(currentPage) else { return }
                scroller.scrollTo(model.pages[currentPage], anchor: .center)
            }
        }
        .background(Color(.secondarySystemBackground), ignoresSafeAreaEdges: .bottom)
        .onChange(of: model.pageCount) { selection = [] }
        .modifier(PageInserter(model: model, index: insertionPoint, isPresented: $isInserting))
    }

    private func cell(index: Int, page: PDFPage) -> some View {
        let isSelected = selection.contains(index)
        let isDropTarget = dropTarget == index

        return VStack(spacing: 6) {
            thumbnail(of: page, isSelected: isSelected)
                .contentShape(.contextMenuPreview, .rect(cornerRadius: 8))
                .contextMenu {
                    PageMenu(model: model, page: index, targets: targets(for: index), insert: startInserting)
                }

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.leading, isDropTarget ? 22 : 0)
        .overlay(alignment: .leading) {
            if isDropTarget {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 180)
                    .padding(.leading, 9)
            }
        }
        .animation(ThumbnailSidebar.dropAnimation, value: isDropTarget)
        .contentShape(.rect)
        .onTapGesture(count: 2) { openPage(index) }
        .simultaneousGesture(TapGesture().onEnded { toggle(index) })
        .draggable(String(index))
        .dropDestination(for: String.self) { items, _ in
            guard let source = items.first.flatMap(Int.init), model.pages.indices.contains(source) else { return false }
            move(from: source, to: index)
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? index : (dropTarget == index ? nil : dropTarget)
        }
    }

    private func thumbnail(of page: PDFPage, isSelected: Bool) -> some View {
        Image(uiImage: thumbnails.image(for: page))
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
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(4)
                }
            }
    }

    private func targets(for index: Int) -> IndexSet {
        selection.contains(index) ? IndexSet(selection) : IndexSet(integer: index)
    }

    private func toggle(_ index: Int) {
        if selection.contains(index) {
            selection.remove(index)
        } else {
            selection.insert(index)
        }
    }

    private func startInserting(at index: Int) {
        insertionPoint = index
        isInserting = true
    }

    private func move(from source: Int, to target: Int) {
        let moving = targets(for: source)
        guard !moving.contains(target) else { return }

        let destination = target > source ? target + 1 : target
        model.movePages(moving, to: destination)

        let start = destination - moving.filter { $0 < destination }.count
        selection = selection.isEmpty ? [] : Set(start..<start + moving.count)
    }
}
