import Observation
import UIKit

@MainActor
@Observable
final class PDFFile: UIDocument {
    @ObservationIgnored lazy var model: PDFModel = {
        let model = PDFModel()
        model.undoManager = undoManager
        return model
    }()

    private(set) var failure: (any Error)?

    @ObservationIgnored private var hasAccess = false

    nonisolated override init(fileURL url: URL) {
        super.init(fileURL: url)
    }

    func openFile() async throws {
        hasAccess = fileURL.startAccessingSecurityScopedResource()
        guard await open() else {
            throw failure ?? CocoaError(.fileReadUnknown)
        }
    }

    func closeFile() async {
        if !documentState.contains(.closed), await !close() {
            failure = CocoaError(.fileWriteUnknown)
        }
        if hasAccess {
            fileURL.stopAccessingSecurityScopedResource()
            hasAccess = false
        }
    }

    func clearFailure() {
        failure = nil
    }

    nonisolated override func contents(forType typeName: String) throws -> Any {
        nonisolated(unsafe) let file = self
        return try MainActor.assumeIsolated {
            try file.model.data()
        }
    }

    nonisolated override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        nonisolated(unsafe) let file = self
        try MainActor.assumeIsolated {
            try file.model.load(data)
        }
    }

    nonisolated override func handleError(_ error: any Error, userInteractionPermitted: Bool) {
        nonisolated(unsafe) let file = self
        Task { @MainActor in
            file.failure = error
        }
        finishedHandlingError(error, recovered: false)
    }
}
