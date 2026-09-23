//
//  QuireDocument.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class QuireDocument: Document {

    static let readableContentTypes: [UTType] = [.pdf]

    var pdf: PDFDocument

    init(pdf: PDFDocument = PDFDocument()) {
        self.pdf = pdf
    }

    /// Reads the file's bytes off the main actor.
    ///
    /// The snapshot type is `Data` rather than `PDFDocument` because reading and
    /// writing happen off the main actor, and only sendable values may cross that
    /// boundary.
    nonisolated func reader(
        configuration: sending ReadConfiguration
    ) -> sending FileWrapperDocumentReader<Data> {
        FileWrapperDocumentReader(configuration) { fileWrapper in
            guard let data = fileWrapper.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return data
        }
    }

    nonisolated func writer(
        configuration: sending WriteConfiguration
    ) -> sending FileWrapperDocumentWriter<Data> {
        FileWrapperDocumentWriter(configuration) { snapshot, _ in
            FileWrapper(regularFileWithContents: snapshot)
        }
    }

    @MainActor
    func snapshot(contentType: UTType) async throws -> sending Data {
        guard let data = pdf.dataRepresentation() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    @MainActor
    func apply(snapshot: sending Data, previous: sending Data?) async throws {
        guard let pdf = PDFDocument(data: snapshot) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if pdf.isLocked {
            throw CocoaError(.fileReadNoPermission)
        }
        self.pdf = pdf
    }
}
