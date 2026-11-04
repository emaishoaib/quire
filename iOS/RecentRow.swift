import SwiftUI

struct RecentRow: View {
    let recents: RecentFiles
    let showAll: () -> Void
    let open: (RecentFile) -> Void

    @State private var width = 0.0

    private var visibleCount: Int {
        max(Int((width + 12) / (FileTile.width + 12)), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                Spacer()
                if recents.files.count > visibleCount {
                    Button("Show more", action: showAll)
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.cream)

            HStack(alignment: .top, spacing: 12) {
                ForEach(recents.files.prefix(visibleCount)) { file in
                    FileTile(name: file.name, image: recents.thumbnail(of: file)) {
                        open(file)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
    }
}

struct AllRecentsView: View {
    let recents: RecentFiles
    let open: (RecentFile) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: FileTile.width), spacing: 16)], spacing: 20) {
                    ForEach(recents.files) { file in
                        FileTile(name: file.name, image: recents.thumbnail(of: file)) {
                            open(file)
                        }
                    }
                }
                .padding()
            }
            .background(Color.wine)
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
