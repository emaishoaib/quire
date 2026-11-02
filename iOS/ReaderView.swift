import SwiftUI

struct OpenedPDF: Identifiable {
    let id = UUID()
    let name: String
    let file: PDFFile
}

struct ReaderView: View {
    let pdf: OpenedPDF

    @State private var controller = ViewerController()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFViewer(pdf: pdf.file.model.pdf, controller: controller)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(pdf.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: close)
                    }
                }
        }
        .alert("Couldn't Save the PDF", isPresented: showingFailure) {
            Button("OK", action: acknowledgeFailure)
        } message: {
            Text(pdf.file.failure?.localizedDescription ?? "")
        }
    }

    private var showingFailure: Binding<Bool> {
        Binding(
            get: { pdf.file.failure != nil },
            set: { _ in }
        )
    }

    private func close() {
        Task {
            await pdf.file.closeFile()
            if pdf.file.failure == nil {
                dismiss()
            }
        }
    }

    private func acknowledgeFailure() {
        pdf.file.clearFailure()
        if pdf.file.documentState.contains(.closed) {
            dismiss()
        }
    }
}
