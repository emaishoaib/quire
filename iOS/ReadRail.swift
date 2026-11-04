import SwiftUI

struct ReadRail: View {
    private static let width = 68.0
    private static let buttonSize = 44.0

    let viewer: ViewerController
    let pageCount: Int
    let find: () -> Void
    @Binding var mode: Mode
    @Binding var showsSidebar: Bool
    @Binding var sidebarTab: SidebarTab

    var body: some View {
        VStack(spacing: 8) {
            button("Find", systemImage: "magnifyingglass", action: find)

            separator

            button(
                mode == .read ? "Organise Pages" : "Read",
                systemImage: mode == .read ? "square.grid.2x2" : "doc.text"
            ) {
                withAnimation(Mode.animation) {
                    mode = mode == .read ? .pages : .read
                    showsSidebar = false
                }
            }

            if mode == .read {
                button("Show or Hide Sidebar", systemImage: "sidebar.left") {
                    showsSidebar.toggle()
                }
                .transition(.opacity)
            }

            if mode == .read && showsSidebar {
                let other: SidebarTab = sidebarTab == .thumbnails ? .contents : .thumbnails
                button("Show \(other.rawValue)", systemImage: other.systemImage) {
                    sidebarTab = other
                }
                .contentTransition(.symbolEffect(.replace))
                .transition(.opacity)
            }

            Spacer(minLength: 20)

            if mode == .read {
                Group {
                    PageIndicator(viewer: viewer, pageCount: pageCount)

                    separator

                    ZoomMenu(viewer: viewer, width: Self.width - 12, height: Self.buttonSize)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(width: Self.width)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
    }

    private var separator: some View {
        Divider()
            .frame(width: 26)
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
