import SwiftUI

struct FileRow: View {
    private static let previewWidth = 36.0
    private static let previewHeight = 48.0

    let name: String
    var detail: String?
    let preview: FileTile.Preview
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                previewView
                    .frame(width: Self.previewWidth, height: Self.previewHeight)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(Color.cream)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.cream.opacity(0.6))
                    }
                }

                Spacer(minLength: 0)

                if case .folder = preview {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color.cream.opacity(0.4))
                }
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var previewView: some View {
        switch preview {
        case .page(let image):
            page(image)
                .frame(width: Self.previewWidth, height: Self.previewHeight)
                .background(Color.cream)
                .clipShape(.rect(cornerRadius: 3))
        case .folder:
            Image(systemName: "folder.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.cream)
        }
    }

    @ViewBuilder
    private func page(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc.text")
                .foregroundStyle(Color.wine)
        }
    }
}
