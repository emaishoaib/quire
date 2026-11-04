import SwiftUI

struct HomeView: View {
    @State private var recents = RecentFiles()
    @State private var library = LibraryFiles()
    @State private var showsAllRecents = false
    @State private var chosenRecent: RecentFile?
    @State private var opened: OpenedPDF?
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Wordmark(height: 44)

            if !recents.files.isEmpty {
                RecentRow(recents: recents, showAll: { showsAllRecents = true }, open: open)
            }

            LibrarySection(library: library) { url in
                open(url)
            }
        }
        .padding([.top, .horizontal], 24)
        .background(Color.wine)
        .preferredColorScheme(.dark)
        .task { await library.refresh() }
        .sheet(isPresented: $showsAllRecents, onDismiss: openChosenRecent) {
            AllRecentsView(recents: recents) { file in
                chosenRecent = file
                showsAllRecents = false
            }
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

    private func openChosenRecent() {
        guard let chosenRecent else { return }
        self.chosenRecent = nil
        open(chosenRecent)
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
