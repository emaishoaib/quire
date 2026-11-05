import Foundation
import Observation

@MainActor
@Observable
final class Places {
    private static let key = "placeBookmarks"

    private(set) var urls: [URL] = []

    init() {
        let bookmarks = UserDefaults.standard.array(forKey: Self.key) as? [Data] ?? []
        urls = bookmarks.compactMap(Self.resolve)
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
        }
        save()
    }

    func contains(_ url: URL) -> Bool {
        urls.contains { $0.path == url.path }
    }

    func add(_ url: URL) {
        guard !contains(url) else { return }
        _ = url.startAccessingSecurityScopedResource()
        urls.append(url)
        save()
    }

    func remove(_ url: URL) {
        guard let place = urls.first(where: { $0.path == url.path }) else { return }
        place.stopAccessingSecurityScopedResource()
        urls.removeAll { $0.path == url.path }
        save()
    }

    private func save() {
        UserDefaults.standard.set(urls.compactMap { try? $0.bookmarkData() }, forKey: Self.key)
    }

    private static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    }
}
