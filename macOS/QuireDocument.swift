import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class QuireDocument: NSDocument {
    var pdf = PDFDocument()
    var revision = 0

    var pages: [PDFPage] = []

    @ObservationIgnored weak var viewer: ViewerController?

    nonisolated override class var autosavesInPlace: Bool { false }

    override func makeWindowControllers() {
        Workspace.shared.open(self)
    }

    override func showWindows() {
        Workspace.shared.show(self)
    }

    override func close() {
        savePosition()
        Workspace.shared.remove(self)
        super.close()
    }

    func savePosition() {
        guard let fileURL, let position = viewer?.position else { return }
        ReadingPositions.save(position, for: fileURL)
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        if isDocumentEdited {
            Workspace.shared.show(self)
        }
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    @objc func exportCopy(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = exportName
        panel.message = "Export a copy of this PDF"

        let write: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do {
                try data(ofType: "com.adobe.pdf").write(to: url)
            } catch {
                presentError(error)
            }
        }

        if let window = windowControllers.first?.window {
            panel.beginSheetModal(for: window, completionHandler: write)
        } else {
            write(panel.runModal())
        }
    }

    private var exportName: String {
        let base = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        return "\(base) copy.pdf"
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = pdf.dataRepresentation() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        guard let parsed = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if parsed.isLocked {
            throw CocoaError(.fileReadNoPermission)
        }
        MainActor.assumeIsolated {
            pdf = parsed
            pages = (0..<parsed.pageCount).compactMap { parsed.page(at: $0) }
            revision += 1
        }
    }
}
