import SwiftUI

enum FolderChange {
    case deeper
    case back
    case swipedBack
    case swipedForward

    var transition: AnyTransition {
        switch self {
        case .deeper: .push(from: .trailing)
        case .back: .push(from: .leading)
        case .swipedBack: .asymmetric(insertion: .move(edge: .leading), removal: .identity)
        case .swipedForward: .asymmetric(insertion: .move(edge: .trailing), removal: .identity)
        }
    }
}
