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
    private let places = Places()
    private let deviceStorageName = "On My \(UIDevice.current.model)"
    private(set) var items: [LibraryItem] = []
    private(set) var hasLoaded = false
    private(set) var folders: [URL] = []
    private var foldersAhead: [URL] = []

    var canGoBack: Bool { !folders.isEmpty }
    var canGoForward: Bool { !foldersAhead.isEmpty }

    var title: String {
        folders.last.map { Self.name(of: $0, deviceStorageName: deviceStorageName) } ?? "Browse"
    }

    var isInQuireFolder: Bool { folders.count == 1 && Self.isQuireFolder(folders[0]) }

    func refresh() async {
        let folder = folders.last
        let items = await Self.items(in: folder, places: places.urls, deviceStorageName: deviceStorageName)
        guard folder == folders.last else { return }
        self.items = items
        hasLoaded = true
    }

    func isAddedPlace(_ url: URL) -> Bool {
        folders.isEmpty && places.contains(url)
    }

    func addPlace(_ url: URL) async {
        places.add(url)
        await refresh()
    }

    func removePlace(_ url: URL) async {
        places.remove(url)
        foldersAhead.removeAll()
        await refresh()
    }

    func open(_ folder: URL) async {
        folders.append(folder)
        foldersAhead.removeAll()
        hasLoaded = false
        await refresh()
    }

    func createFolder(named name: String) async throws {
        guard let folder = folders.last else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = folder.appending(path: trimmed.isEmpty ? "Untitled Folder" : trimmed, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        await refresh()
    }

    func goBack() async {
        guard let folder = folders.popLast() else { return }
        foldersAhead.append(folder)
        hasLoaded = false
        await refresh()
    }

    func goForward() async {
        guard let folder = foldersAhead.popLast() else { return }
        folders.append(folder)
        hasLoaded = false
        await refresh()
    }

    @concurrent
    private nonisolated static func items(in folder: URL?, places: [URL], deviceStorageName: String) async -> [LibraryItem] {
        guard let folder else {
            return ([.documentsDirectory] + places).map { place(at: $0, deviceStorageName: deviceStorageName) }
        }
        let urls = contents(of: folder).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        let folders = urls.filter(isFolder).map {
            LibraryItem(url: $0, name: $0.lastPathComponent, kind: .folder(itemCount: contents(of: $0).count))
        }
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }.map(pdf(at:))
        return folders + pdfs
    }

    private nonisolated static func place(at url: URL, deviceStorageName: String) -> LibraryItem {
        LibraryItem(
            url: url,
            name: name(of: url, deviceStorageName: deviceStorageName),
            kind: .folder(itemCount: contents(of: url).count)
        )
    }

    private nonisolated static func name(of folder: URL, deviceStorageName: String) -> String {
        guard !isQuireFolder(folder) else { return "Quire" }
        switch folder.lastPathComponent {
        case "File Provider Storage": return deviceStorageName
        case "com~apple~CloudDocs": return "iCloud Drive"
        default: return (try? folder.resourceValues(forKeys: [.localizedNameKey]))?.localizedName ?? folder.lastPathComponent
        }
    }

    private nonisolated static func isQuireFolder(_ folder: URL) -> Bool {
        folder.standardizedFileURL.path == URL.documentsDirectory.standardizedFileURL.path
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

    nonisolated static func pdf(at url: URL) -> LibraryItem {
        let pdf = PDFDocument(url: url)
        let thumbnail = pdf?.page(at: 0)?.thumbnail(of: CGSize(width: 252, height: 336), for: .cropBox)
        return LibraryItem(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            kind: .pdf(pageCount: pdf?.pageCount ?? 0, thumbnail: thumbnail)
        )
    }
}
