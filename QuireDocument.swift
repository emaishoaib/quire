//
//  QuireDocument.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A PDF open in a window.
///
/// `revision` is bumped after every page edit. `PDFDocument` is a PDFKit object that
/// `@Observable` cannot see inside, so moving or rotating a page changes nothing SwiftUI
/// watches, and views observe the counter instead.
@Observable
final class QuireDocument: Document {

    static let readableContentTypes: [UTType] = [.pdf]

    var pdf: PDFDocument
    private(set) var revision = 0

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
        revision += 1
    }
}

/// A page together with the rotation it should carry.
struct PageState {
    let page: PDFPage
    let rotation: Int
}

extension QuireDocument {

    var pageCount: Int { pdf.pageCount }

    var pageStates: [PageState] {
        (0..<pdf.pageCount).compactMap { pdf.page(at: $0) }.map {
            PageState(page: $0, rotation: $0.rotation)
        }
    }

    /// Replaces every page with `newState` and registers the reverse as undo.
    ///
    /// Every edit goes through here, so undo is always "put the old list back" and
    /// each new operation gets working undo without its own bookkeeping.
    func applyPages(_ newState: [PageState], actionName: String, undoManager: UndoManager?) {
        let oldState = pageStates

        for index in stride(from: pdf.pageCount - 1, through: 0, by: -1) {
            pdf.removePage(at: index)
        }
        for (index, item) in newState.enumerated() {
            item.page.rotation = item.rotation
            pdf.insert(item.page, at: index)
        }
        revision += 1

        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.applyPages(oldState, actionName: actionName, undoManager: undoManager)
            }
        }
        undoManager?.setActionName(actionName)
    }

    func movePages(_ indices: IndexSet, to destination: Int, undoManager: UndoManager?) {
        var newState = pageStates
        newState.move(fromOffsets: indices, toOffset: destination)
        applyPages(newState, actionName: "Move Pages", undoManager: undoManager)
    }

    func rotatePages(_ indices: IndexSet, by degrees: Int, undoManager: UndoManager?) {
        let newState = pageStates.enumerated().map { index, item in
            guard indices.contains(index) else { return item }
            let rotation = ((item.rotation + degrees) % 360 + 360) % 360
            return PageState(page: item.page, rotation: rotation)
        }
        applyPages(newState, actionName: "Rotate Pages", undoManager: undoManager)
    }

    /// Deletes the given pages, unless that would empty the document.
    ///
    /// A PDF with no pages cannot be written back to disk, so the last page stays.
    func deletePages(_ indices: IndexSet, undoManager: UndoManager?) {
        guard indices.count < pageCount else { return }
        let newState = pageStates.enumerated()
            .filter { !indices.contains($0.offset) }
            .map(\.element)
        applyPages(newState, actionName: "Delete Pages", undoManager: undoManager)
    }

    /// Inserts copies of every page of the PDF at `url`, and reports how many were added.
    ///
    /// The pages are copied because a `PDFPage` belongs to one document at a time, and
    /// moving them would strip the pages out of the document being inserted from.
    @discardableResult
    func insertPages(from url: URL, at index: Int, undoManager: UndoManager?) throws -> Int {
        guard let other = PDFDocument(url: url), !other.isLocked else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let inserted = (0..<other.pageCount).compactMap { index -> PageState? in
            guard let copy = other.page(at: index)?.copy() as? PDFPage else { return nil }
            return PageState(page: copy, rotation: copy.rotation)
        }
        guard !inserted.isEmpty else { return 0 }

        var newState = pageStates
        newState.insert(contentsOf: inserted, at: min(index, newState.count))
        applyPages(newState, actionName: "Insert Pages", undoManager: undoManager)
        return inserted.count
    }
}
