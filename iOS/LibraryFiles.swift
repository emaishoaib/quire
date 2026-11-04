import Foundation
import Observation
import PDFKit
import UIKit

nonisolated struct LibraryItem: Identifiable, Sendable {
    enum Kind: Sendable {
        case folder(itemCount: Int)
        case pdf(pageCount: Int, thumbnail: UIImage?)
    }

    let url: URL
    let name: String
    let kind: Kind

    var id: URL { url }
}

@MainActor
@Observable
final class LibraryFiles {
    private(set) var items: [LibraryItem] = []
    private(set) var hasLoaded = false
    private(set) var folders: [URL] = []

    var folder: URL { folders.last ?? .documentsDirectory }

    func refresh() async {
        let folder = folder
        let items = await Self.items(in: folder)
        guard folder == self.folder else { return }
        self.items = items
        hasLoaded = true
    }

    func open(_ folder: URL) async {
        folders.append(folder)
        hasLoaded = false
        await refresh()
    }

    func goBack() async {
        guard !folders.isEmpty else { return }
        folders.removeLast()
        hasLoaded = false
        await refresh()
    }

    @concurrent
    private nonisolated static func items(in folder: URL) async -> [LibraryItem] {
        let urls = contents(of: folder).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        let folders = urls.filter(isFolder).map {
            LibraryItem(url: $0, name: $0.lastPathComponent, kind: .folder(itemCount: contents(of: $0).count))
        }
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }.map(pdf(at:))
        return folders + pdfs
    }

    private nonisolated static func contents(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []
    }

    private nonisolated static func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private nonisolated static func pdf(at url: URL) -> LibraryItem {
        let pdf = PDFDocument(url: url)
        let thumbnail = pdf?.page(at: 0)?.thumbnail(of: CGSize(width: 252, height: 336), for: .cropBox)
        return LibraryItem(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            kind: .pdf(pageCount: pdf?.pageCount ?? 0, thumbnail: thumbnail)
        )
    }
}
