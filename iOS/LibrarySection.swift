import SwiftUI
import UniformTypeIdentifiers

struct LibrarySection: View {
    let library: LibraryFiles
    let open: (URL) -> Void

    @State private var isNamingFolder = false
    @State private var folderName = ""
    @State private var folderFailure: String?
    @State private var isAddingPlace = false
    @State private var movingItem: URL?
    @State private var moveFailure: String?
    @State private var visibleHeight = 0.0
    @State private var slide = FolderSlide()
    @AppStorage(LibraryLayout.storageKey) private var layout = LibraryLayout.grid

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            header

            ZStack {
                folderList
                    .id(library.listedFolder)
                    .transition(.asymmetric(insertion: .move(edge: slide.arrivalEdge), removal: .opacity.animation(nil)))
            }
            .animation(.snappy, value: library.listedFolder)
            .folderSwipe(
                slide,
                canGoBack: library.canGoBack,
                canGoForward: library.canGoForward,
                goBack: { await library.goBack() },
                goForward: { await library.goForward() }
            )
            .padding(.horizontal, -HomeLayout.margin)
            .onGeometryChange(for: Double.self) { $0.size.height } action: { visibleHeight = $0 }
        }
        .fileImporter(isPresented: $isAddingPlace, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await library.addPlace(url) }
        }
        .fileMover(isPresented: isMoving, file: movingItem) { result in
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                moveFailure = error.localizedDescription
            }
            Task { await library.refresh() }
        }
        .alert("Couldn't Move It", isPresented: showingMoveFailure) {
            Button("OK") {}
        } message: {
            Text(moveFailure ?? "")
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

    private var folderList: some View {
        PullToRefreshScrollView {
            await library.refresh()
        } content: {
            content
                .padding(.top, 8)
                .padding(.bottom, 24)
                .padding(.horizontal, HomeLayout.margin)
                .frame(maxWidth: .infinity, minHeight: visibleHeight, alignment: .top)
                .contentShape(.rect)
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.hasLoaded && library.items.isEmpty {
            EmptyLibrary(isQuireFolder: library.isInQuireFolder)
        } else {
            FileCollection(items: library.items, tile: tile, row: row)
        }
    }

    private var isMoving: Binding<Bool> {
        Binding(
            get: { movingItem != nil },
            set: { if !$0 { movingItem = nil } }
        )
    }

    private var showingMoveFailure: Binding<Bool> {
        Binding(
            get: { moveFailure != nil },
            set: { if !$0 { moveFailure = nil } }
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
                    slide.leave(.back) { await library.goBack() }
                }
                .labelStyle(.iconOnly)
            }

            Text(library.title)
            Spacer()
            HStack(spacing: 24) {
                Button(layout.switchTitle, systemImage: layout.switchSymbol) { layout = layout.other }

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

    private func tile(_ item: LibraryItem) -> some View {
        FileTile(name: item.name, detail: detail(of: item), preview: preview(of: item)) { activate(item) }
            .contextMenu { menu(for: item) }
    }

    private func row(_ item: LibraryItem) -> some View {
        FileRow(name: item.name, detail: detail(of: item), preview: preview(of: item)) { activate(item) }
            .contextMenu { menu(for: item) }
    }

    private func detail(of item: LibraryItem) -> String {
        switch item.kind {
        case .folder(let itemCount): count(itemCount, "item")
        case .pdf(let pageCount, _): count(pageCount, "page")
        }
    }

    private func preview(of item: LibraryItem) -> FileTile.Preview {
        switch item.kind {
        case .folder: .folder
        case .pdf(_, let thumbnail): .page(thumbnail)
        }
    }

    private func activate(_ item: LibraryItem) {
        switch item.kind {
        case .folder:
            slide.leave(.forward) { await library.open(item.url) }
        case .pdf: open(item.url)
        }
    }

    @ViewBuilder
    private func menu(for item: LibraryItem) -> some View {
        if library.isAddedPlace(item.url) {
            Button("Remove Location", systemImage: "minus.circle", role: .destructive) {
                Task { await library.removePlace(item.url) }
            }
        } else if !library.folders.isEmpty {
            Button("Move", systemImage: "folder") { movingItem = item.url }
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
