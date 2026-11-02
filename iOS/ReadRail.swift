import SwiftUI

struct ReadRail: View {
    private static let width = 68.0
    private static let buttonSize = 44.0
    private static let zoomPresets = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4]

    let viewer: ViewerController
    let pageCount: Int
    let find: () -> Void
    @Binding var showsSidebar: Bool
    @Binding var sidebarTab: SidebarTab

    var body: some View {
        VStack(spacing: 8) {
            button("Find", systemImage: "magnifyingglass", action: find)

            separator

            button("Show or Hide Sidebar", systemImage: "sidebar.left") {
                showsSidebar.toggle()
            }

            if showsSidebar {
                let other: SidebarTab = sidebarTab == .thumbnails ? .contents : .thumbnails
                button("Show \(other.rawValue)", systemImage: other.systemImage) {
                    sidebarTab = other
                }
                .contentTransition(.symbolEffect(.replace))
                .transition(.opacity)
            }

            Spacer(minLength: 20)

            PageIndicator(viewer: viewer, pageCount: pageCount)

            separator

            zoomMenu
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(width: Self.width)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
    }

    private var zoomMenu: some View {
        Menu {
            Button("Fit Width") { viewer.fitWidth() }
            Divider()
            ForEach(Self.zoomPresets, id: \.self) { preset in
                Button(percentage(preset)) { viewer.setScale(preset) }
            }
        } label: {
            Text(percentage(viewer.scale))
                .font(.system(size: 13))
                .monospacedDigit()
                .frame(width: Self.width - 12, height: Self.buttonSize)
                .contentShape(.rect)
        }
        .accessibilityLabel("Zoom level and fit options")
    }

    private var separator: some View {
        Divider()
            .frame(width: 26)
    }

    private func percentage(_ scale: Double) -> String {
        scale.formatted(.percent.precision(.fractionLength(0)))
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
