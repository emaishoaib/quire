import SwiftUI

struct OpenedPDF: Identifiable {
    let id = UUID()
    let name: String
    let model: PDFModel
}

struct ReaderView: View {
    let pdf: OpenedPDF

    @State private var controller = ViewerController()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFViewer(pdf: pdf.model.pdf, controller: controller)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(pdf.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
