import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class PDFModel {
    private(set) var pdf = PDFDocument()
    var revision = 0

    var pages: [PDFPage] = []

    @ObservationIgnored weak var undoManager: UndoManager?

    func load(_ data: Data) throws {
        guard let parsed = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if parsed.isLocked {
            throw CocoaError(.fileReadNoPermission)
        }
        pdf = parsed
        pages = (0..<parsed.pageCount).compactMap { parsed.page(at: $0) }
        revision += 1
    }

    func data() throws -> Data {
        guard let data = pdf.dataRepresentation() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
