//
//  HighlightBar.swift
//  Quire
//
//  Created by Mustafa Shoaib on 10/7/26.
//

import SwiftUI

/// A colour text can be highlighted in.
enum HighlightColour: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: Self { self }

    var name: String { rawValue.capitalized }

    var colour: NSColor {
        switch self {
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }
}

/// Where the selected text sits in the Read view, for the highlight bar to place itself by.
///
/// Both rectangles are in the view's own coordinates, measured from its top-left corner
/// the way SwiftUI measures. A selection on one line has the same rectangle for both.
struct SelectionAnchor {
    let firstLine: CGRect
    let lastLine: CGRect
}

/// The row of colour dots that floats beside selected text.
///
/// It has no Highlight button: clicking a dot is what highlights, in that dot's colour.
/// The colour used last comes first, so highlighting in it again is the nearest click.
struct HighlightBar: View {
    /// How the bar arrives and leaves.
    ///
    /// Set where the anchor changes rather than in the view, because a view being
    /// inserted or removed cannot animate its own arrival.
    static let animation = Animation.spring(duration: 0.22, bounce: 0.2)

    private static let dot = 18.0
    private static let spacing = 8.0
    private static let padding = CGSize(width: 10, height: 7)
    private static let gap = 8.0
    private static let margin = 8.0

    /// The bar's size, worked out from its parts so it can be placed before it is drawn.
    static var size: CGSize {
        let count = Double(HighlightColour.allCases.count)
        return CGSize(
            width: count * dot + (count - 1) * spacing + padding.width * 2,
            height: dot + padding.height * 2
        )
    }

    /// Where the bar's centre goes in a view of `container` size.
    ///
    /// The bar sits above the first line of the selection. When there is no room there,
    /// which includes the first line having scrolled off the top, it sits below the last
    /// line instead. A selection that fills the view leaves room in neither place, and the
    /// bar is then pinned to the top of the view. It is always kept within the view's sides.
    static func centre(for anchor: SelectionAnchor, in container: CGSize) -> CGPoint {
        let above = anchor.firstLine.minY - gap - size.height
        let below = anchor.lastLine.maxY + gap

        let top: CGFloat
        let middle: CGFloat
        if above >= margin {
            top = above
            middle = anchor.firstLine.midX
        } else if below + size.height <= container.height - margin {
            top = below
            middle = anchor.lastLine.midX
        } else {
            top = margin
            middle = anchor.firstLine.midX
        }

        let half = size.width / 2
        let x = min(max(middle, margin + half), container.width - margin - half)
        return CGPoint(x: x, y: top + size.height / 2)
    }

    let pick: (HighlightColour) -> Void

    @State private var colours: [HighlightColour]

    /// Puts the colour used last at the front, with the rest after it in their usual order.
    ///
    /// The order is fixed when the bar appears rather than read as it is drawn. Picking
    /// a colour changes which one was used last, and the dots would otherwise swap places
    /// while the bar is fading out.
    init(lastUsed: HighlightColour, pick: @escaping (HighlightColour) -> Void) {
        _colours = State(initialValue: [lastUsed] + HighlightColour.allCases.filter { $0 != lastUsed })
        self.pick = pick
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(colours) { colour in
                Button {
                    pick(colour)
                } label: {
                    Circle()
                        .fill(Color(nsColor: colour.colour))
                        .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                        .frame(width: Self.dot, height: Self.dot)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help(colour.name)
                .accessibilityLabel(colour.name)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }
}
