import SwiftUI

struct LibrarySection: View {
    let library: LibraryFiles
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            header

            if library.hasLoaded && library.items.isEmpty {
                EmptyLibrary(isTopLevel: library.folders.isEmpty)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16, alignment: .top)],
                    alignment: .leading,
                    spacing: 20
                ) {
                    ForEach(library.items, content: tile)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if !library.folders.isEmpty {
                Button("Back", systemImage: "chevron.left") {
                    Task { await library.goBack() }
                }
                .labelStyle(.iconOnly)
            }

            Text(library.folders.last?.lastPathComponent ?? "Library")
            Spacer()
            Button("Refresh Library", systemImage: "arrow.clockwise") {
                Task { await library.refresh() }
            }
            .labelStyle(.iconOnly)
        }
        .font(.subheadline)
        .foregroundStyle(Color.cream)
    }

    private func tile(_ item: LibraryItem) -> some View {
        switch item.kind {
        case .folder(let itemCount):
            FileTile(name: item.name, detail: count(itemCount, "item"), preview: .folder) {
                Task { await library.open(item.url) }
            }
        case .pdf(let pageCount, let thumbnail):
            FileTile(name: item.name, detail: count(pageCount, "page"), preview: .page(thumbnail)) {
                open(item.url)
            }
        }
    }

    private func count(_ number: Int, _ noun: String) -> String {
        number == 1 ? "1 \(noun)" : "\(number) \(noun)s"
    }
}

private struct EmptyLibrary: View {
    let isTopLevel: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isTopLevel ? "tray" : "folder")
                .font(.system(size: 36))
            Text(isTopLevel ? "Your library is empty" : "This folder is empty")
                .font(.headline)
            if isTopLevel {
                Text("Move PDFs into Quire's folder in the Files app to see them here.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .opacity(0.7)
            }
        }
        .foregroundStyle(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
