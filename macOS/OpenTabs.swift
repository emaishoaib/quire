import Foundation

/// The files open in the tab strip and the one selected, kept as bookmarks so they are found again after a move or rename.
enum OpenTabs {
    private static let filesKey = "openTabFiles"
    private static let selectedKey = "selectedOpenTabFile"

    static var files: [URL] {
        let bookmarks = UserDefaults.standard.array(forKey: filesKey) as? [Data] ?? []
        return bookmarks.compactMap(resolve)
    }

    static var selected: URL? {
        UserDefaults.standard.data(forKey: selectedKey).flatMap(resolve)
    }

    static func save(_ files: [URL], selected: URL?) {
        UserDefaults.standard.set(files.compactMap { try? $0.bookmarkData() }, forKey: filesKey)
        UserDefaults.standard.set(selected.flatMap { try? $0.bookmarkData() }, forKey: selectedKey)
    }

    private static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
    }
}
