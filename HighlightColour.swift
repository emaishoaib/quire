import SwiftUI

enum HighlightColour: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: Self { self }

    var name: String { rawValue.capitalized }

    var dot: NSColor {
        switch self {
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }

    var colour: NSColor {
        switch self {
        case .yellow: NSColor(srgbRed: 1, green: 0.941, blue: 0.478, alpha: 1)
        case .green: NSColor(srgbRed: 0.659, green: 0.902, blue: 0.631, alpha: 1)
        case .blue: NSColor(srgbRed: 0.647, green: 0.824, blue: 1, alpha: 1)
        case .pink: NSColor(srgbRed: 1, green: 0.69, blue: 0.784, alpha: 1)
        case .purple: NSColor(srgbRed: 0.851, green: 0.722, blue: 0.961, alpha: 1)
        }
    }
}
