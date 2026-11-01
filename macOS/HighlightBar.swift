import SwiftUI

struct SelectionAnchor {
    let firstLine: CGRect
    let lastLine: CGRect
}

struct HighlightBar: View {
    static let animation = Animation.spring(duration: 0.22, bounce: 0.2)

    private static let dot = 18.0
    private static let spacing = 8.0
    private static let divider = 1.0
    private static let padding = CGSize(width: 10, height: 7)
    private static let gap = 8.0
    private static let margin = 8.0

    static func size(hasRemove: Bool) -> CGSize {
        let count = Double(HighlightColour.allCases.count)
        let dots = count * dot + (count - 1) * spacing
        let remove = hasRemove ? spacing + divider + spacing + dot : 0
        return CGSize(
            width: dots + remove + padding.width * 2,
            height: dot + padding.height * 2
        )
    }

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
