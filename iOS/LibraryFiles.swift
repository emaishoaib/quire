import Foundation
import Observation
import PDFKit
import UIKit

nonisolated struct LibraryFile: Identifiable, Sendable {
    let url: URL
    let name: String
    let pageCount: Int
    let thumbnail: UIImage?

    var id: URL { url }
}

@MainActor
@Observable
final class LibraryFiles {
    private(set) var files: [LibraryFile] = []
    private(set) var hasLoaded = false

    func refresh() async {
        files = await Self.files(in: .documentsDirectory)
        hasLoaded = true
    }

    @concurrent
    private nonisolated static func files(in folder: URL) async -> [LibraryFile] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(file(at:))
    }

    private nonisolated static func file(at url: URL) -> LibraryFile {
        let pdf = PDFDocument(url: url)
        return LibraryFile(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            pageCount: pdf?.pageCount ?? 0,
            thumbnail: pdf?.page(at: 0)?.thumbnail(of: CGSize(width: 252, height: 336), for: .cropBox)
        )
    }
}
