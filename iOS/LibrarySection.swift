import SwiftUI

struct LibrarySection: View {
    let library: LibraryFiles
    let open: (URL) -> Void

    @State private var isNamingFolder = false
    @State private var folderName = ""
    @State private var folderFailure: String?
    @State private var search: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            header

            if search != nil {
                LibrarySearchField(text: searchText) { search = nil }
            }

            PullToRefreshScrollView {
                await library.refresh()
            } content: {
                content
                    .padding(.bottom, 24)
            }
            .backSwipe(isEnabled: !library.folders.isEmpty) {
                await library.goBack()
            }
        }
        .onChange(of: library.folders) { search = nil }
        .alert("New Folder", isPresented: $isNamingFolder) {
            TextField("Name", text: $folderName)
            Button("Cancel", role: .cancel) {}
            Button("Create", action: createFolder)
        }
        .alert("Couldn't Create the Folder", isPresented: showingFolderFailure) {
            Button("OK") {}
        } message: {
            Text(folderFailure ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.hasLoaded && library.items.isEmpty {
            EmptyLibrary(isTopLevel: library.folders.isEmpty)
        } else if library.hasLoaded && visibleItems.isEmpty {
            Text("No matches in this folder")
                .font(.headline)
                .foregroundStyle(Color.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(visibleItems, content: tile)
            }
        }
    }

    private var visibleItems: [LibraryItem] {
        guard let search, !search.isEmpty else { return library.items }
        return library.items.filter { $0.name.localizedStandardContains(search) }
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search ?? "" },
            set: { search = $0 }
        )
    }

    private var showingFolderFailure: Binding<Bool> {
        Binding(
            get: { folderFailure != nil },
            set: { if !$0 { folderFailure = nil } }
        )
    }

    private func createFolder() {
        let name = folderName
        Task {
            do {
                try await library.createFolder(named: name)
            } catch {
                folderFailure = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if !library.folders.isEmpty {
                Button("Back", systemImage: "chevron.left") {
                    Task { await library.goBack() }
                }
                .labelStyle(.iconOnly)
            }

            Text(library.folders.last?.lastPathComponent ?? "Library")
            Spacer()
            HStack(spacing: 24) {
                Button("New Folder", systemImage: "folder.badge.plus") {
                    folderName = ""
                    isNamingFolder = true
                }
                Button("Search", systemImage: "magnifyingglass") {
                    search = search == nil ? "" : nil
                }
            }
            .labelStyle(.iconOnly)
        }
        .font(.title3)
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
