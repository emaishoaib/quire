import SwiftUI

extension Color {
    static let wine = Color(.sRGB, red: 0.231, green: 0.059, blue: 0.125)
    static let cream = Color(.sRGB, red: 0.969, green: 0.937, blue: 0.886)
}

struct FileTile: View {
    static let width = 84.0

    let name: String
    var detail: String?
    let image: UIImage?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 4) {
                preview
                    .frame(width: Self.width, height: 112)
                    .background(Color.cream)
                    .clipShape(.rect(cornerRadius: 4))

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
    private var preview: some View {
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
