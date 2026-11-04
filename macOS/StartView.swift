import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StartView: View {
    @State private var recents = NSDocumentController.shared.recentDocumentURLs
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                if recents.isEmpty {
                    empty
                } else {
                    recentGrid
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: hasAppeared)
        }
        .background(Color.wine)
        .onAppear {
            recents = NSDocumentController.shared.recentDocumentURLs
            hasAppeared = true
        }
    }

    private var header: some View {
        HStack {
            Wordmark(height: 40)

            Spacer()

            Button(action: openPanel) {
                Text("Open…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.wine)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 7)
                    .background(Color.cream, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 32))
            Text("No recent PDFs")
                .font(.headline)
            Text("PDFs you open will appear here.")
                .font(.system(size: 13))
                .opacity(0.7)
        }
        .foregroundStyle(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var recentGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent")
                .font(.system(size: 13))
                .foregroundStyle(Color.cream.opacity(0.7))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: RecentTile.width + 24), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 24
            ) {
                ForEach(Array(recents.enumerated()), id: \.element) { index, url in
                    RecentTile(url: url) { open(url) }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 6)
                        .animation(
                            .easeOut(duration: 0.25).delay(0.08 + Double(index) * 0.035),
                            value: hasAppeared
                        )
                }
            }
        }
    }

    private func openPanel() {
        NSDocumentController.shared.openDocument(nil)
    }

    private func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
}

struct OpeningView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 64, height: 64)

            Text(FileManager.default.displayName(atPath: url.path))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cream)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)

                Text("Opening…")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cream.opacity(0.7))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wine)
        .environment(\.colorScheme, .dark)
    }
}
