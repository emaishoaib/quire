#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

#if os(macOS)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif

enum HighlightColour: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: Self { self }

    var name: String { rawValue.capitalized }

    var dot: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        case .purple: .purple
        }
    }

    var colour: PlatformColor {
        let (red, green, blue): (CGFloat, CGFloat, CGFloat) = switch self {
        case .yellow: (1, 0.941, 0.478)
        case .green: (0.659, 0.902, 0.631)
        case .blue: (0.647, 0.824, 1)
        case .pink: (1, 0.69, 0.784)
        case .purple: (0.851, 0.722, 0.961)
        }
        #if os(macOS)
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        #else
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
        #endif
    }
}
