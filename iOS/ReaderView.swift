import SwiftUI

struct OpenedPDF: Identifiable {
    let id = UUID()
    let name: String
    let file: PDFFile
}

struct ReaderView: View {
    let pdf: OpenedPDF

    @State private var controller = ViewerController()
    @AppStorage("highlightColour") private var highlightColour = HighlightColour.yellow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFViewer(pdf: pdf.file.model.pdf, controller: controller)
                .overlay { highlightBar }
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

    private var highlightBar: some View {
        GeometryReader { proxy in
            if let anchor = controller.selectionAnchor {
                let hasRemove = controller.selectedHighlight != nil
                let centre = HighlightBar.centre(for: anchor, in: proxy.size, hasRemove: hasRemove)
                let origin = UnitPoint(
                    x: centre.x / max(proxy.size.width, 1),
                    y: centre.y / max(proxy.size.height, 1)
                )
                HighlightBar(
                    lastUsed: highlightColour,
                    pick: { colour in
                        highlightColour = colour
                        controller.highlight(in: colour, of: pdf.file.model)
                    },
                    remove: hasRemove ? { controller.removeSelectedHighlight(from: pdf.file.model) } : nil
                )
                .position(centre)
                .transition(.scale(scale: 0.85, anchor: origin).combined(with: .opacity))
            }
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
