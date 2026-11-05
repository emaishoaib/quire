import SwiftUI

struct HomeView: View {
    @State private var recents = RecentFiles()
    @State private var library = LibraryFiles()
    @State private var search = LibrarySearch()
    @State private var opened: OpenedPDF?
    @State private var failure: String?

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                HomePage {
                    LibrarySection(library: library) { url in
                        open(url)
                    }
                }
            }
            Tab("Recent", systemImage: "clock") {
                HomePage {
                    RecentSection(recents: recents, open: open)
                }
            }
            Tab(role: .search) {
                NavigationStack {
                    HomePage {
                        SearchSection(search: search) { url in
                            open(url)
                        }
                    }
                }
            }
        }
        .searchable(text: $search.text, prompt: "Search your library")
        .tint(Color.cream)
        .preferredColorScheme(.dark)
        .task {
            WelcomePDF.createIfNeeded()
            await library.refresh()
        }
        .fullScreenCover(item: $opened, onDismiss: { Task { await library.refresh() } }) { pdf in
            ReaderView(pdf: pdf)
        }
        .alert("Couldn't Open the PDF", isPresented: showingFailure) {
            Button("OK") {}
        } message: {
            Text(failure ?? "")
        }
    }

    private var showingFailure: Binding<Bool> {
        Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )
    }

    private func open(_ file: RecentFile) {
        guard let url = recents.url(of: file) else {
            recents.remove(file)
            return
        }
        open(url, recent: file)
    }

    private func open(_ url: URL, recent: RecentFile? = nil) {
        Task {
            let file = PDFFile(fileURL: url)
            do {
                try await file.openFile()
                recents.add(url, bookmark: try url.bookmarkData(), firstPage: file.model.pages.first)
                opened = OpenedPDF(name: url.deletingPathExtension().lastPathComponent, file: file)
            } catch {
                await file.closeFile()
                if let recent {
                    recents.remove(recent)
                } else {
                    failure = error.localizedDescription
                }
            }
        }
    }
}

private struct HomePage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Wordmark(height: 44)
            content
        }
        .padding([.top, .horizontal], 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.wine)
    }
}
