import SwiftUI

struct SidebarTabSwitch: View {
    private static let animation = Animation.spring(duration: 0.3, bounce: 0.15)
    private static let height = 24.0
    private static let inset = 3.0

    @Binding var selection: SidebarTab

    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SidebarTab.allCases) { tab in
                Button {
                    withAnimation(Self.animation) { selection = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tab == selection ? .primary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background { thumb(for: tab) }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
            }
        }
        .frame(height: Self.height)
        .padding(Self.inset)
        .background(.quaternary, in: .capsule)
    }

    @ViewBuilder
    private func thumb(for tab: SidebarTab) -> some View {
        if tab == selection {
            Capsule()
                .fill(.background)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                .matchedGeometryEffect(id: "thumb", in: thumb)
        }
    }
}
