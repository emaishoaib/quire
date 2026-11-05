import Foundation
import Observation

@MainActor
@Observable
final class LibrarySearch {
    var text = ""
    private(set) var pdfs: [LibraryItem] = []
    private(set) var hasLoaded = false

    var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var results: [LibraryItem] {
        pdfs.filter { $0.name.localizedStandardContains(query) }
    }

    func refresh() async {
        pdfs = await Self.pdfs(under: .documentsDirectory)
        hasLoaded = true
    }

    @concurrent
    private nonisolated static func pdfs(under folder: URL) async -> [LibraryItem] {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        let urls = (enumerator?.allObjects as? [URL]) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(LibraryFiles.pdf(at:))
    }
}
