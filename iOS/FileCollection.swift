import SwiftUI

struct FileCollection<Item: Identifiable, Tile: View, Row: View>: View {
    let items: [Item]
    @ViewBuilder let tile: (Item) -> Tile
    @ViewBuilder let row: (Item) -> Row

    @AppStorage(LibraryLayout.storageKey) private var layout = LibraryLayout.grid

    var body: some View {
        switch layout {
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16, alignment: .bottom)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(items, content: tile)
            }
        case .list:
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    row(item)
                    Divider()
                        .overlay(Color.cream.opacity(0.15))
                }
            }
        }
    }
}
