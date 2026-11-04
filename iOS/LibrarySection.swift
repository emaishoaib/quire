import SwiftUI

struct LibrarySection: View {
    let library: LibraryFiles
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            HStack {
                Text("Library")
                Spacer()
                Button("Refresh Library", systemImage: "arrow.clockwise") {
                    Task { await library.refresh() }
                }
                .labelStyle(.iconOnly)
            }
            .font(.subheadline)
            .foregroundStyle(Color.cream)

            if library.hasLoaded && library.files.isEmpty {
                EmptyLibrary()
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16, alignment: .top)],
                    alignment: .leading,
                    spacing: 20
                ) {
                    ForEach(library.files) { file in
                        FileTile(name: file.name, detail: pages(file.pageCount), image: file.thumbnail) {
                            open(file.url)
                        }
                    }
                }
            }
        }
    }

    private func pages(_ count: Int) -> String {
        count == 1 ? "1 page" : "\(count) pages"
    }
}

private struct EmptyLibrary: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
            Text("Your library is empty")
                .font(.headline)
            Text("Move PDFs into Quire's folder in the Files app to see them here.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .opacity(0.7)
        }
        .foregroundStyle(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
