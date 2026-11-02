import SwiftUI
import UniformTypeIdentifiers

struct PageMenu: View {
    let model: PDFModel
    let page: Int
    let targets: IndexSet
    let insert: (Int) -> Void

    var body: some View {
        Button("Rotate Left", systemImage: "rotate.left") {
            model.rotatePages(targets, by: -90)
        }
        Button("Rotate Right", systemImage: "rotate.right") {
            model.rotatePages(targets, by: 90)
        }

        Divider()

        Button("Insert Pages Before", systemImage: "doc.badge.plus") {
            insert(page)
        }
        Button("Insert Pages After", systemImage: "doc.badge.plus") {
            insert(page + 1)
        }

        Divider()

        Button(targets.count > 1 ? "Delete \(targets.count) Pages" : "Delete Page", systemImage: "trash", role: .destructive) {
            model.deletePages(targets)
        }
        .disabled(targets.count >= model.pageCount)
    }
}

struct PageInserter: ViewModifier {
    let model: PDFModel
    let index: Int
    @Binding var isPresented: Bool

    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                insert(urls)
            }
            .alert("Couldn't insert those pages", isPresented: $failed) {
                Button("OK") {}
            } message: {
                Text("One of the files could not be read. It may be damaged or password protected.")
            }
    }

    private func insert(_ urls: [URL]) {
        var insertAt = index
        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                insertAt += try model.insertPages(from: url, at: insertAt)
            } catch {
                failed = true
                return
            }
        }
    }
}
