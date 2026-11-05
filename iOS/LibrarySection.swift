import SwiftUI
import UniformTypeIdentifiers

struct LibrarySection: View {
    let library: LibraryFiles
    let open: (URL) -> Void

    @State private var isNamingFolder = false
    @State private var folderName = ""
    @State private var folderFailure: String?
    @State private var isAddingPlace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            header

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
        .fileImporter(isPresented: $isAddingPlace, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await library.addPlace(url) }
        }
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
            EmptyLibrary(isQuireFolder: library.isInQuireFolder)
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

            Text(library.title)
            Spacer()
            Group {
                if library.folders.isEmpty {
                    Button("Add Location", systemImage: "plus") { isAddingPlace = true }
                } else {
                    Button("New Folder", systemImage: "folder.badge.plus") {
                        folderName = ""
                        isNamingFolder = true
                    }
                }
            }
            .labelStyle(.iconOnly)
        }
        .font(.title3)
        .foregroundStyle(Color.cream)
    }

    @ViewBuilder
    private func tile(_ item: LibraryItem) -> some View {
        switch item.kind {
        case .folder(let itemCount):
            FileTile(name: item.name, detail: count(itemCount, "item"), preview: .folder) {
                Task { await library.open(item.url) }
            }
            .contextMenu {
                if library.isAddedPlace(item.url) {
                    Button("Remove Location", systemImage: "minus.circle", role: .destructive) {
                        Task { await library.removePlace(item.url) }
                    }
                }
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
    let isQuireFolder: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isQuireFolder ? "tray" : "folder")
                .font(.system(size: 36))
            Text(isQuireFolder ? "Quire's folder is empty" : "This folder is empty")
                .font(.headline)
            if isQuireFolder {
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
