import SwiftUI

struct RecentSection: View {
    let recents: RecentFiles
    let open: (RecentFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cream.opacity(0.25))

            Text("Recent")
                .font(.title3)
                .foregroundStyle(Color.cream)

            ScrollView {
                content
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if recents.files.isEmpty {
            EmptyRecents()
        } else {
            FileCollection(items: recents.files) { file in
                FileTile(name: file.name, preview: .page(recents.thumbnail(of: file))) {
                    open(file)
                }
            } row: { file in
                FileRow(name: file.name, preview: .page(recents.thumbnail(of: file))) {
                    open(file)
                }
            }
        }
    }
}

private struct EmptyRecents: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 36))
            Text("No recent files")
                .font(.headline)
            Text("PDFs you open will show up here.")
                .font(.subheadline)
                .opacity(0.7)
        }
        .foregroundStyle(Color.cream)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
