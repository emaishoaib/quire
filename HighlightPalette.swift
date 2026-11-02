import SwiftUI

struct HighlightPalette: View {
    static let animation = Animation.spring(duration: 0.28, bounce: 0.2)

    private static let dot = 18.0
    private static let spacing = 12.0
    private static let padding = CGSize(width: 9, height: 12)

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

struct HighlightButtonKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
