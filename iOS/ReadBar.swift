import SwiftUI

struct ReadBar: View {
    private static let buttonSize = 44.0
    private static let zoomWidth = 56.0
    private static let zoomHeight = 36.0
    private static let bottomGap = 16.0

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

                button(
                    viewer.isHighlighting ? "Stop Highlighting" : "Highlight",
                    systemImage: "highlighter"
                ) {
                    withAnimation(HighlightPalette.animation) {
                        viewer.setHighlighting(!viewer.isHighlighting)
                    }
                }
                .foregroundStyle(viewer.isHighlighting ? Color.yellow : Color.primary)
                .opacity(mode == .read ? 1 : 0)
                .disabled(mode != .read)

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
        .padding(.top, 4)
        .padding(.bottom, Self.bottomGap)
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
