import CoreTransferable
import UniformTypeIdentifiers

nonisolated struct SharedPDF: Transferable {
    let name: String
    let model: PDFModel

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { pdf in
            try await pdf.model.data()
        }
        .suggestedFileName { $0.name }
    }
}
