import SwiftUI

struct FileTile: View {
    enum Preview {
        case page(UIImage?)
        case folder
    }

    static let width = 84.0
    private static let height = 112.0

    let name: String
    var detail: String?
    let preview: Preview
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 4) {
                previewView
                    .frame(width: Self.width, height: Self.height)

                Text(name)
                    .font(.caption)
                    .foregroundStyle(Color.cream)
                    .lineLimit(1)
                    .frame(width: Self.width)

                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Color.cream.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var previewView: some View {
        switch preview {
        case .page(let image):
            page(image)
                .frame(width: Self.width, height: Self.height)
                .background(Color.cream)
                .clipShape(.rect(cornerRadius: 4))
        case .folder:
            Image(systemName: "folder.fill")
                .font(.system(size: 64))
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
