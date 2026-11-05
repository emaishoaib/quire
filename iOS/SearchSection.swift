import SwiftUI

struct SearchSection: View {
    let search: LibrarySearch
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            Text("Search")
                .font(.title3)
                .foregroundStyle(Color.cream)

            ScrollView {
                content
                    .padding(.bottom, 24)
            }
        }
        .task { await search.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        if search.query.isEmpty {
            SearchMessage(symbol: "magnifyingglass", title: "Search your library", detail: "Find a PDF by name in any folder.")
        } else if search.hasLoaded && search.results.isEmpty {
            SearchMessage(symbol: "doc.questionmark", title: "No matches", detail: nil)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(search.results, content: tile)
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: LibraryItem) -> some View {
        if case .pdf(let pageCount, let thumbnail) = item.kind {
            FileTile(name: item.name, detail: pageCount == 1 ? "1 page" : "\(pageCount) pages", preview: .page(thumbnail)) {
                open(item.url)
            }
        }
    }
}

private struct SearchMessage: View {
    let symbol: String
    let title: String
    let detail: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 36))
            Text(title)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .opacity(0.7)
            }
        }
        .foregroundStyle(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
