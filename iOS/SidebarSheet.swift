import SwiftUI

struct SidebarSheet: View {
    let model: PDFModel
    let viewer: ViewerController
    let thumbnailWidth: Double
    @Binding var tab: SidebarTab

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .thumbnails:
                    ThumbnailSidebar(model: model, viewer: viewer, thumbnailWidth: thumbnailWidth) { dismiss() }
                case .contents:
                    ContentsSidebar(model: model, viewer: viewer) { dismiss() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Sidebar", selection: $tab) {
                        ForEach(SidebarTab.allCases) { tab in
                            Text(tab.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
