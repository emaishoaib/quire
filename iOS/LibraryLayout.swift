enum LibraryLayout: String {
    case grid
    case list

    static let storageKey = "libraryLayout"

    var other: LibraryLayout {
        switch self {
        case .grid: .list
        case .list: .grid
        }
    }

    var switchTitle: String {
        switch self {
        case .grid: "Show as List"
        case .list: "Show as Grid"
        }
    }

    var switchSymbol: String {
        switch self {
        case .grid: "list.bullet"
        case .list: "square.grid.2x2"
        }
    }
}
