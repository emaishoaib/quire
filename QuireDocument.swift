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

    /// The pages in order.
    ///
    /// Stored rather than read from `pdf` on demand, because `PDFDocument` is a PDFKit
    /// object that `@Observable` cannot see inside: views watch this array, and a page
    /// keeps its identity across a reorder, which is what lets a move animate as a move.
    private(set) var pages: [PDFPage] = []

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
        WindowTabs.prepare(window)
        addWindowController(NSWindowController(window: window))
    }

    /// Shows this document's window as a tab of whatever Quire window is already open.
    override func showWindows() {
        guard let window = windowControllers.first?.window else {
            super.showWindows()
            return
        }
        WindowTabs.show(window, replacingStartTabs: true)
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
            pages = (0..<parsed.pageCount).compactMap { parsed.page(at: $0) }
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

    /// How page edits animate in the grid and the sidebar.
    ///
    /// Applied where the pages change rather than in the views: a page being inserted or
    /// removed is not covered by `animation(_:value:)` in the view that draws it.
    static let editAnimation = Animation.spring(duration: 0.3, bounce: 0.15)

    var pageCount: Int { pages.count }

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
        withAnimation(Self.editAnimation) {
            pages = newState.map(\.page)
            revision += 1
        }

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

extension QuireDocument {

    /// What may follow this file's name in the name of a file that belongs with it.
    ///
    /// Requiring one of these keeps `Lease.pdf` from claiming `Leasehold.pdf`, whose name
    /// only happens to start the same way.
    private static let nameSeparators: Set<Character> = [" ", "-", "_", ".", "("]

    /// The PDFs in this file's folder whose names are its name with something added.
    ///
    /// For `Lease.pdf` that is `Lease 2.pdf`, `Lease-signed.pdf`, `Lease (1).pdf` and so
    /// on, sorted the way Finder sorts them, so `Lease 2` comes before `Lease 10`. Case is
    /// ignored, as it is by the Mac's file system. A document that has never been saved
    /// has no folder, and finds nothing.
    func similarlyNamedFiles() -> [URL] {
        guard let fileURL else { return [] }
        let base = fileURL.deletingPathExtension().lastPathComponent
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        return contents
            .filter { url in
                guard url.pathExtension.lowercased() == "pdf" else { return false }
                let name = url.deletingPathExtension().lastPathComponent
                guard let match = name.range(of: base, options: [.anchored, .caseInsensitive]),
                      match.upperBound < name.endIndex
                else { return false }
                return Self.nameSeparators.contains(name[match.upperBound])
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
