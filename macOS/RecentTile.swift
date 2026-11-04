import AppKit
import PDFKit
import SwiftUI

struct RecentTile: View {
    static let width = 96.0
    private static let height = 128.0

    let url: URL
    let open: () -> Void

    @State private var thumbnail: CGImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            VStack(spacing: 3) {
                page
                    .frame(width: Self.width, height: Self.height)
                    .background(Color.cream)
                    .clipShape(.rect(cornerRadius: 4))
                    .scaleEffect(isHovered ? 1.04 : 1)
                    .shadow(color: .black.opacity(isHovered ? 0.35 : 0), radius: 8, y: 3)
                    .padding(.bottom, 4)

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cream)

                Text(folder)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cream.opacity(0.6))
            }
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: Self.width + 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(url.path)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.2)) { isHovered = hovering }
        }
        .task { thumbnail = await Self.thumbnail(of: url) }
    }

    @ViewBuilder
    private var page: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 2)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundStyle(Color.wine)
        }
    }

    private var folder: String {
        url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    @concurrent
    private nonisolated static func thumbnail(of url: URL) async -> CGImage? {
        let image = PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 192, height: 256), for: .cropBox)
        return image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
