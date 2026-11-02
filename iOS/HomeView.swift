import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private extension Color {
    static let wine = Color(.sRGB, red: 0.231, green: 0.059, blue: 0.125)
    static let cream = Color(.sRGB, red: 0.969, green: 0.937, blue: 0.886)
}

struct HomeView: View {
    @State private var recents = RecentFiles()
    @State private var isPicking = false
    @State private var showsAllRecents = false
    @State private var chosenRecent: RecentFile?
    @State private var opened: OpenedPDF?
    @State private var failure: String?

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height

            ZStack(alignment: isWide ? .bottomTrailing : .bottomLeading) {
                Color.wine
                mark(in: proxy.size, isWide: isWide)
                controls(in: proxy.size, isWide: isWide)
                    .padding(32)
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .ignoresSafeArea(edges: .top)
        .background(Color.wine)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                open(url)
            case .failure(let error):
                failure = error.localizedDescription
            }
        }
        .sheet(isPresented: $showsAllRecents, onDismiss: openChosenRecent) {
            AllRecentsView(recents: recents) { file in
                chosenRecent = file
                showsAllRecents = false
            }
        }
        .fullScreenCover(item: $opened) { pdf in
            ReaderView(pdf: pdf)
        }
        .alert("Couldn't Open the PDF", isPresented: showingFailure) {
            Button("OK") {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func mark(in size: CGSize, isWide: Bool) -> some View {
        let unit = isWide ? size.height : min(size.width, (size.height - 360) / 1.05)
        let side = unit * 1.89

        return Image("QuireMark")
            .resizable()
            .frame(width: side, height: side)
            .position(x: side / 2 - unit * 0.7, y: side / 2 - unit * 0.5)
            .accessibilityHidden(true)
    }

    private func controls(in size: CGSize, isWide: Bool) -> some View {
        let width = isWide ? size.width / 2 : size.width - 64
        let visibleCount = max(Int((width + 12) / 96), 1)

        return VStack(alignment: isWide ? .trailing : .leading, spacing: 20) {
            Text("Quire")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.cream)

            if !recents.files.isEmpty {
                recentRow(visibleCount: visibleCount)
            }

            Button {
                isPicking = true
            } label: {
                Text("Browse")
                    .font(.headline)
                    .foregroundStyle(Color.wine)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(Color.cream, in: .capsule)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: width, alignment: isWide ? .trailing : .leading)
    }

    private func recentRow(visibleCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                Spacer()
                if recents.files.count > visibleCount {
                    Button("Show more") {
                        showsAllRecents = true
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.cream)

            HStack(alignment: .top, spacing: 12) {
                ForEach(recents.files.prefix(visibleCount)) { file in
                    RecentThumbnail(file: file, image: recents.thumbnail(of: file)) {
                        open(file)
                    }
                }
            }
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
            do {
                let contents = try await Task.detached { try Self.contents(of: url) }.value
                let model = PDFModel()
                try model.load(contents.data)
                recents.add(url, bookmark: contents.bookmark, firstPage: model.pages.first)
                opened = OpenedPDF(name: url.deletingPathExtension().lastPathComponent, model: model)
            } catch {
                if let recent {
                    recents.remove(recent)
                } else {
                    failure = error.localizedDescription
                }
            }
        }
    }

    private nonisolated static func contents(of url: URL) throws -> FileContents {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var coordinationError: NSError?
        var result: Result<Data, any Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            result = Result { try Data(contentsOf: readable) }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw CocoaError(.fileReadUnknown)
        }
        return FileContents(data: try result.get(), bookmark: try url.bookmarkData())
    }
}

private struct FileContents: Sendable {
    let data: Data
    let bookmark: Data
}

private struct RecentThumbnail: View {
    let file: RecentFile
    let image: UIImage?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 4) {
                preview
                    .frame(width: 84, height: 112)
                    .background(Color.cream)
                    .clipShape(.rect(cornerRadius: 4))

                Text(file.name)
                    .font(.caption)
                    .foregroundStyle(Color.cream)
                    .lineLimit(1)
                    .frame(width: 84)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.name)
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc.text")
                .foregroundStyle(Color.wine)
        }
    }
}

private struct AllRecentsView: View {
    let recents: RecentFiles
    let open: (RecentFile) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 16)], spacing: 20) {
                    ForEach(recents.files) { file in
                        RecentThumbnail(file: file, image: recents.thumbnail(of: file)) {
                            open(file)
                        }
                    }
                }
                .padding()
            }
            .background(Color.wine)
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
