import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    private static let wine = Color(.sRGB, red: 0.231, green: 0.059, blue: 0.125)
    private static let cream = Color(.sRGB, red: 0.969, green: 0.937, blue: 0.886)

    @State private var isPicking = false
    @State private var opened: OpenedPDF?
    @State private var failure: String?

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height

            ZStack(alignment: isWide ? .bottomTrailing : .bottomLeading) {
                Self.wine
                mark(in: proxy.size)
                controls(alignment: isWide ? .trailing : .leading)
                    .padding(32)
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .ignoresSafeArea(edges: .top)
        .background(Self.wine)
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
        .fullScreenCover(item: $opened) { pdf in
            OpenedPDFView(pdf: pdf)
        }
        .alert("Couldn't Open the PDF", isPresented: showingFailure) {
            Button("OK") {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func mark(in size: CGSize) -> some View {
        let unit = min(size.width, size.height)
        let side = unit * 1.89

        return Image("QuireMark")
            .resizable()
            .frame(width: side, height: side)
            .position(x: side / 2 - unit * 0.7, y: side / 2 - unit * 0.5)
            .accessibilityHidden(true)
    }

    private func controls(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 20) {
            Text("Quire")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Self.cream)

            Button {
                isPicking = true
            } label: {
                Text("Open PDF")
                    .font(.headline)
                    .foregroundStyle(Self.wine)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Self.cream, in: .capsule)
            }
        }
    }

    private var showingFailure: Binding<Bool> {
        Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )
    }

    private func open(_ url: URL) {
        Task {
            do {
                let data = try await Task.detached { try Self.contents(of: url) }.value
                let model = PDFModel()
                try model.load(data)
                opened = OpenedPDF(name: url.deletingPathExtension().lastPathComponent, model: model)
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    private nonisolated static func contents(of url: URL) throws -> Data {
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
        return try result.get()
    }
}

private struct OpenedPDF: Identifiable {
    let id = UUID()
    let name: String
    let model: PDFModel
}

private struct OpenedPDFView: View {
    let pdf: OpenedPDF

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                pdf.name,
                systemImage: "doc.text",
                description: Text("^[\(pdf.model.pageCount) page](inflect: true)")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
