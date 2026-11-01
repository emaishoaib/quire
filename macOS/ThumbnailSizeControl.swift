import SwiftUI

struct ThumbnailSizeControl: View {
    @Binding var thumbnailWidth: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.portrait")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            Slider(value: $thumbnailWidth, in: 60...220)
                .controlSize(.mini)

            Image(systemName: "rectangle.portrait")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
