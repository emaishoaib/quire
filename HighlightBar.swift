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

    /// The colour of this choice's dot in the highlight bar.
    ///
    /// The dots are full strength so they stand apart from one another at their small
    /// size, and are deliberately stronger than the highlight each one makes.
    var dot: NSColor {
        switch self {
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .pink: .systemPink
        case .purple: .systemPurple
        }
    }

    /// The colour the text is highlighted in, a paler form of the dot's.
    ///
    /// A highlight sits behind whole lines of text, where the dot's full strength reads
    /// as heavy and pulls the eye away from the words.
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
///
/// Opened by clicking a highlight rather than by selecting text, the dots recolour that
/// highlight, and a remove button joins them.
struct HighlightBar: View {
    /// How the bar arrives and leaves.
    ///
    /// Set where the anchor changes rather than in the view, because a view being
    /// inserted or removed cannot animate its own arrival.
    static let animation = Animation.spring(duration: 0.22, bounce: 0.2)

    private static let dot = 18.0
    private static let spacing = 8.0
    private static let divider = 1.0
    private static let padding = CGSize(width: 10, height: 7)
    private static let gap = 8.0
    private static let margin = 8.0

    /// The bar's size, worked out from its parts so it can be placed before it is drawn.
    ///
    /// The remove button adds its own width, and that of the line dividing it from the dots.
    static func size(hasRemove: Bool) -> CGSize {
        let count = Double(HighlightColour.allCases.count)
        let dots = count * dot + (count - 1) * spacing
        let remove = hasRemove ? spacing + divider + spacing + dot : 0
        return CGSize(
            width: dots + remove + padding.width * 2,
            height: dot + padding.height * 2
        )
    }

    /// Where the bar's centre goes in a view of `container` size.
    ///
    /// The bar sits above the first line of the selection. When there is no room there,
    /// which includes the first line having scrolled off the top, it sits below the last
    /// line instead. A selection that fills the view leaves room in neither place, and the
    /// bar is then pinned to the top of the view. It is always kept within the view's sides.
    static func centre(for anchor: SelectionAnchor, in container: CGSize, hasRemove: Bool) -> CGPoint {
        let size = size(hasRemove: hasRemove)
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
    let remove: (() -> Void)?

    @State private var colours: [HighlightColour]

    /// Puts the colour used last at the front, with the rest after it in their usual order.
    ///
    /// The order is fixed when the bar appears rather than read as it is drawn. Picking
    /// a colour changes which one was used last, and the dots would otherwise swap places
    /// while the bar is fading out.
    init(lastUsed: HighlightColour, pick: @escaping (HighlightColour) -> Void, remove: (() -> Void)?) {
        _colours = State(initialValue: [lastUsed] + HighlightColour.allCases.filter { $0 != lastUsed })
        self.pick = pick
        self.remove = remove
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(colours) { colour in
                Button {
                    pick(colour)
                } label: {
                    Circle()
                        .fill(Color(nsColor: colour.dot))
                        .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                        .frame(width: Self.dot, height: Self.dot)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help(colour.name)
                .accessibilityLabel(colour.name)
            }

            if let remove {
                Rectangle()
                    .fill(.separator)
                    .frame(width: Self.divider, height: Self.dot)

                Button(action: remove) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: Self.dot, height: Self.dot)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Remove Highlight")
                .accessibilityLabel("Remove Highlight")
            }
        }
        .frame(width: Self.size(hasRemove: remove != nil).width, height: Self.size(hasRemove: remove != nil).height)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }
}

/// The column of colour dots that stands beside the rail while highlight mode is on.
///
/// It sets the colour the next drag highlights in. Unlike the bar beside selected text,
/// it stays put for as long as the mode is on, so its dots keep one order and the colour
/// in use is ringed instead of being moved to the front.
struct HighlightPalette: View {
    /// How the palette comes out of the rail's highlight button and goes back into it.
    ///
    /// Set where highlight mode changes rather than in the view, because a view being
    /// inserted or removed cannot animate its own arrival.
    static let animation = Animation.spring(duration: 0.28, bounce: 0.2)

    private static let dot = 18.0
    private static let spacing = 12.0
    private static let padding = CGSize(width: 9, height: 12)

    /// The palette's size, worked out from its parts so it can be placed before it is drawn.
    static var size: CGSize {
        let count = Double(HighlightColour.allCases.count)
        return CGSize(
            width: dot + padding.width * 2,
            height: count * dot + (count - 1) * spacing + padding.height * 2
        )
    }

    @Binding var selected: HighlightColour

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(HighlightColour.allCases) { colour in
                Button {
                    selected = colour
                } label: {
                    Circle()
                        .fill(Color(nsColor: colour.dot))
                        .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                        .frame(width: Self.dot, height: Self.dot)
                        .overlay {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 1.5)
                                .padding(-4)
                                .opacity(colour == selected ? 1 : 0)
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help(colour.name)
                .accessibilityLabel(colour.name)
                .accessibilityAddTraits(colour == selected ? .isSelected : [])
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Reports where the rail's highlight button is, for the palette to come out beside it.
struct HighlightButtonKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
