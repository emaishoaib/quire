import SwiftUI

struct ReadBar: View {
    private static let buttonSize = 44.0
    private static let zoomWidth = 56.0
    private static let zoomHeight = 36.0

    let viewer: ViewerController
    let pageCount: Int
    let find: () -> Void
    @Binding var mode: Mode
    @Binding var showsSidebar: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                button("Show Sidebar", systemImage: "sidebar.left") {
                    showsSidebar = true
                }
                .opacity(mode == .read ? 1 : 0)
                .disabled(mode != .read)

                Spacer()

                button(
                    mode == .read ? "Organise Pages" : "Read",
                    systemImage: mode == .read ? "square.grid.2x2" : "doc.text"
                ) {
                    withAnimation(Mode.animation) {
                        mode = mode == .read ? .pages : .read
                    }
                }

                Spacer()

                button("Find", systemImage: "magnifyingglass", action: find)
            }

            if mode == .read {
                ZStack(alignment: .trailing) {
                    PageIndicator(viewer: viewer, pageCount: pageCount, isInline: true)
                        .frame(maxWidth: .infinity)

                    ZoomMenu(viewer: viewer, width: Self.zoomWidth, height: Self.zoomHeight)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar, ignoresSafeAreaEdges: [.bottom, .horizontal])
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
