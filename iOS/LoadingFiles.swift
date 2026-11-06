import SwiftUI

struct LoadingFiles: View {
    private static var placeholderCount: Int { 6 }
    private static var delayBeforeShowing: Duration { .milliseconds(150) }

    private struct Placeholder: Identifiable {
        let id: Int
    }

    @State private var isShowing = false

    var body: some View {
        FileCollection(
            items: (0..<Self.placeholderCount).map(Placeholder.init),
            tile: { _ in PlaceholderTile() },
            row: { _ in PlaceholderRow() }
        )
        .foregroundStyle(Color.cream.opacity(0.2))
        .phaseAnimator([false, true]) { content, isBright in
            content.opacity(isBright ? 1 : 0.4)
        } animation: { _ in
            .easeInOut(duration: 0.8)
        }
        .opacity(isShowing ? 1 : 0)
        .task {
            try? await Task.sleep(for: Self.delayBeforeShowing)
            withAnimation(.easeIn(duration: 0.2)) { isShowing = true }
        }
        .accessibilityLabel("Loading")
    }
}

private struct PlaceholderTile: View {
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .frame(width: FileTile.width, height: FileTile.height)
            Capsule()
                .frame(width: FileTile.width * 0.7, height: 8)
            Capsule()
                .frame(width: FileTile.width * 0.4, height: 6)
        }
    }
}

private struct PlaceholderRow: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .frame(width: FileRow.previewWidth, height: FileRow.previewHeight)
            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .frame(width: 160, height: 10)
                Capsule()
                    .frame(width: 70, height: 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}
