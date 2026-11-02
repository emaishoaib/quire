import Foundation
import Observation
import PDFKit
import UIKit

struct RecentFile: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let bookmark: Data
}

@MainActor
@Observable
final class RecentFiles {
    private static let key = "recentFiles"
    private static let limit = 20

    private(set) var files: [RecentFile]

    init() {
        let saved = UserDefaults.standard.data(forKey: Self.key)
        files = saved.flatMap { try? JSONDecoder().decode([RecentFile].self, from: $0) } ?? []
        for file in files where url(of: file) == nil {
            remove(file)
        }
    }

    func url(of file: RecentFile) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &isStale)
    }

    func add(_ url: URL, bookmark: Data, firstPage: PDFPage?) {
        let path = url.resolvingSymlinksInPath().path
        let id = files.first { $0.path == path }?.id ?? UUID()
        let name = url.deletingPathExtension().lastPathComponent

        files.removeAll { $0.path == path }
        files.insert(RecentFile(id: id, name: name, path: path, bookmark: bookmark), at: 0)
        for file in files.dropFirst(Self.limit) {
            remove(file)
        }

        let image = firstPage?.thumbnail(of: CGSize(width: 252, height: 336), for: .cropBox)
        try? image?.jpegData(compressionQuality: 0.8)?.write(to: thumbnailURL(of: id))
        save()
    }

    func remove(_ file: RecentFile) {
        files.removeAll { $0.id == file.id }
        try? FileManager.default.removeItem(at: thumbnailURL(of: file.id))
        save()
    }

    func thumbnail(of file: RecentFile) -> UIImage? {
        UIImage(contentsOfFile: thumbnailURL(of: file.id).path)
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(files), forKey: Self.key)
    }

    private func thumbnailURL(of id: UUID) -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: "RecentThumbnails")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "\(id.uuidString).jpg")
    }
}
