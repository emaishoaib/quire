//
//  QuireDocument.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A PDF open in a window.
///
/// This is an `NSDocument` rather than a SwiftUI document because SwiftUI's
/// `DocumentGroup` always autosaves in place and offers no way to turn that off. Owning
/// the document means edits stay in memory until saved, and closing or quitting with
/// unsaved work prompts, which AppKit provides once `autosavesInPlace` is false.
///
/// `revision` is bumped after every page edit. `PDFDocument` is a PDFKit object that
/// `@Observable` cannot see inside, so moving or rotating a page changes nothing SwiftUI
/// watches, and views observe the counter instead.
@Observable
final class QuireDocument: NSDocument {

    var pdf = PDFDocument()
    private(set) var revision = 0

    nonisolated override class var autosavesInPlace: Bool { false }

    /// Builds the window.
    ///
    /// `sizingOptions` is emptied so the hosting controller stops pushing SwiftUI's
    /// preferred size onto the window: without that, switching between Read and Pages
    /// resizes the window under the user.
    override func makeWindowControllers() {
        let hosting = NSHostingController(rootView: ContentView(document: self))
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 1180, height: 820))
        window.minSize = NSSize(width: 720, height: 520)
        window.setFrameAutosaveName("QuireDocumentWindow")
        addWindowController(NSWindowController(window: window))
    }

    /// Writes the current pages to another file, leaving this document where it is.
    ///
    /// Save As would hand the document over to the new file and carry on editing there.
    /// Export leaves the document attached to its own file, and does not clear its
    /// unsaved changes, so exporting is never mistaken for saving.
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

    /// Parses the file's bytes.
    ///
    /// AppKit declares this as not belonging to the main actor, but it only reads
    /// concurrently when a document class asks to, which this one does not. The parsed
    /// document is therefore handed over on the main actor it already arrived on.
    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        guard let parsed = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if parsed.isLocked {
            throw CocoaError(.fileReadNoPermission)
        }
        MainActor.assumeIsolated {
            pdf = parsed
            revision += 1
        }
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
    /// each new operation gets working undo without its own bookkeeping. Registering
    /// undo is also what marks the document as having unsaved changes.
    func applyPages(_ newState: [PageState], actionName: String) {
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
                document.applyPages(oldState, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }

    func movePages(_ indices: IndexSet, to destination: Int) {
        var newState = pageStates
        newState.move(fromOffsets: indices, toOffset: destination)
        applyPages(newState, actionName: "Move Pages")
    }

    func rotatePages(_ indices: IndexSet, by degrees: Int) {
        let newState = pageStates.enumerated().map { index, item in
            guard indices.contains(index) else { return item }
            let rotation = ((item.rotation + degrees) % 360 + 360) % 360
            return PageState(page: item.page, rotation: rotation)
        }
        applyPages(newState, actionName: "Rotate Pages")
    }

    /// Deletes the given pages, unless that would empty the document.
    ///
    /// A PDF with no pages cannot be written back to disk, so the last page stays.
    func deletePages(_ indices: IndexSet) {
        guard indices.count < pageCount else { return }
        let newState = pageStates.enumerated()
            .filter { !indices.contains($0.offset) }
            .map(\.element)
        applyPages(newState, actionName: "Delete Pages")
    }

    /// Inserts copies of every page of the PDF at `url`, and reports how many were added.
    ///
    /// The pages are copied because a `PDFPage` belongs to one document at a time, and
    /// moving them would strip the pages out of the document being inserted from.
    @discardableResult
    func insertPages(from url: URL, at index: Int) throws -> Int {
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
        applyPages(newState, actionName: "Insert Pages")
        return inserted.count
    }
}
