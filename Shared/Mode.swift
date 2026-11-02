import SwiftUI

enum Mode: String, CaseIterable, Identifiable {
    case read = "Read"
    case pages = "Pages"

    var id: Self { self }

    static let animation = Animation.spring(duration: 0.32, bounce: 0.1)
}
