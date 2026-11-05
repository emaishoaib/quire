import SwiftUI

struct PagePill: View {
    private static let zoomWidth = 52.0
    private static let zoomHeight = 30.0
    private static let visibleAfterActivity = Duration.seconds(2)

    let viewer: ViewerController
    let pageCount: Int
    let activity: Int

    @State private var isVisible = true
    @State private var isEditing = false
    @State private var hiding: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            PageIndicator(viewer: viewer, pageCount: pageCount, isInline: true) { editing in
                isEditing = editing
                reveal()
            }

            Text("·")
                .foregroundStyle(.secondary)

            ZoomMenu(viewer: viewer, width: Self.zoomWidth, height: Self.zoomHeight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(in: .capsule)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .onAppear(perform: reveal)
        .onChange(of: activity, reveal)
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.2)) { isVisible = true }
        hiding?.cancel()
        guard !isEditing else { return }
        hiding = Task {
            try? await Task.sleep(for: Self.visibleAfterActivity)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.4)) { isVisible = false }
        }
    }
}
