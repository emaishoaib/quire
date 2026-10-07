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

/// A PDF open in a tab.
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

    /// Opens this document as a tab of Quire's window, rather than in a window of its own.
    override func makeWindowControllers() {
        Workspace.shared.open(self)
    }

    /// Brings this document's tab to the front.
    override func showWindows() {
        Workspace.shared.show(self)
    }

    /// Closes the document, and its tab with it.
    ///
    /// The tab goes first, which hands the window to another tab. AppKit closes the
    /// windows of a closing document, and would otherwise close the one every tab shares.
    override func close() {
        Workspace.shared.remove(self)
        super.close()
    }

    /// Asks about unsaved changes with this document's tab showing.
    ///
    /// The question is a sheet on the document's window, and only the showing tab has
    /// one. Asked from a tab in the background, it would appear attached to nothing, and
    /// the user could not see which PDF it was about.
    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        if isDocumentEdited {
            Workspace.shared.show(self)
        }
        super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
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

    /// Inserts the file at `url`, and reports how many pages were added.
    ///
    /// A PDF adds a copy of every page it has. An image adds one page that shows it.
    @discardableResult
    func insertPages(from url: URL, at index: Int) throws -> Int {
        let inserted = try Self.isImage(url)
            ? [Self.imagePage(of: url)]
            : Self.copiedPages(of: url)
        guard !inserted.isEmpty else { return 0 }

        var newState = pageStates
        newState.insert(contentsOf: inserted, at: min(index, newState.count))
        applyPages(newState, actionName: "Insert Pages")
        return inserted.count
    }

    /// Copies of every page of the PDF at `url`.
    ///
    /// The pages are copied because a `PDFPage` belongs to one document at a time, and
    /// moving them would strip the pages out of the document they are read from.
    private static func copiedPages(of url: URL) throws -> [PageState] {
        guard let other = PDFDocument(url: url), !other.isLocked else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (0..<other.pageCount).compactMap { index -> PageState? in
            guard let copy = other.page(at: index)?.copy() as? PDFPage else { return nil }
            return PageState(page: copy, rotation: copy.rotation)
        }
    }

    /// Whether the file at `url` is an image, going by its extension.
    static func isImage(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    /// A page showing the image at `url`, at the image's own size.
    ///
    /// That size is the one the file states for print: its pixels divided by its dots per
    /// inch. A file that states no resolution is taken at 72 dots per inch, which makes
    /// each pixel one point.
    ///
    /// The image is read through ImageIO rather than `NSImage(contentsOf:)`, which gives
    /// the pixels exactly as stored. A camera stores a photo held upright as a sideways
    /// picture with a note saying which way is up, so that note is read here and becomes
    /// the page's rotation.
    ///
    /// Only the first picture of a file that holds several is used.
    private static func imagePage(of url: URL) throws -> PageState {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let pixels = CGImageSourceCreateImageAtIndex(source, 0, nil),
              pixels.width > 0, pixels.height > 0
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let rotation = switch orientation {
        case 3, 4: 180
        case 5, 6: 90
        case 7, 8: 270
        default: 0
        }

        let size = NSSize(
            width: CGFloat(pixels.width) * 72 / dotsPerInch(properties, kCGImagePropertyDPIWidth),
            height: CGFloat(pixels.height) * 72 / dotsPerInch(properties, kCGImagePropertyDPIHeight)
        )

        guard let page = PDFPage(image: NSImage(cgImage: pixels, size: size)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return PageState(page: page, rotation: rotation)
    }

    /// The resolution an image file states under `key`, or 72 when it states none.
    private static func dotsPerInch(_ properties: [CFString: Any]?, _ key: CFString) -> CGFloat {
        guard let stated = properties?[key] as? Double, stated > 0 else { return 72 }
        return stated
    }
}

/// A highlight together with the page it is drawn on.
///
/// The page is kept alongside because a highlight that has been taken off its page no
/// longer knows which page that was, and undo needs to put it back.
struct Highlight {
    let annotation: PDFAnnotation
    let page: PDFPage

    /// Whether the highlight is still on its page, which undo may have taken it off.
    var isOnPage: Bool { annotation.page === page }

    /// The highlighted lines, each as a rectangle on the page.
    ///
    /// These come from the corners the annotation lists, four to a line. A highlight
    /// that lists none is taken to cover its whole bounds.
    var lines: [CGRect] {
        let origin = annotation.bounds.origin
        let corners = (annotation.quadrilateralPoints ?? []).map(\.pointValue)
        let lines = stride(from: 0, to: corners.count - 3, by: 4).map { start in
            let line = corners[start..<start + 4]
            let xs = line.map(\.x)
            let ys = line.map(\.y)
            return CGRect(
                x: origin.x + (xs.min() ?? 0),
                y: origin.y + (ys.min() ?? 0),
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
        }
        return lines.isEmpty ? [annotation.bounds] : lines
    }
}

extension QuireDocument {

    /// Highlights the selected text in `colour`.
    ///
    /// The highlight is stored the way the PDF format stores one, as an annotation on the
    /// page, so it is written into the file on save and other PDF readers show it too.
    ///
    /// A selection gets one annotation for each page it touches, however many lines it
    /// covers there, so those lines stay one highlight. The annotation lists the corners
    /// of every line, which is how a highlight follows the text rather than covering the
    /// whole block the lines sit in.
    func highlight(_ selection: PDFSelection, in colour: HighlightColour) {
        var linesByPage: [(page: PDFPage, lines: [CGRect])] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let rect = line.bounds(for: page)
                guard !rect.isEmpty else { continue }
                if let index = linesByPage.firstIndex(where: { $0.page === page }) {
                    linesByPage[index].lines.append(rect)
                } else {
                    linesByPage.append((page, [rect]))
                }
            }
        }

        let highlights = linesByPage.map { page, lines in
            let bounds = lines.dropFirst().reduce(lines[0]) { $0.union($1) }
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = colour.colour
            annotation.quadrilateralPoints = lines.flatMap { line in
                [
                    NSPoint(x: line.minX - bounds.minX, y: line.maxY - bounds.minY),
                    NSPoint(x: line.maxX - bounds.minX, y: line.maxY - bounds.minY),
                    NSPoint(x: line.minX - bounds.minX, y: line.minY - bounds.minY),
                    NSPoint(x: line.maxX - bounds.minX, y: line.minY - bounds.minY)
                ].map { NSValue(point: $0) }
            }
            return Highlight(annotation: annotation, page: page)
        }
        guard !highlights.isEmpty else { return }
        setHighlights(highlights, shown: true, actionName: "Highlight")
    }

    func removeHighlight(_ highlight: Highlight) {
        setHighlights([highlight], shown: false, actionName: "Remove Highlight")
    }

    func recolourHighlight(_ highlight: Highlight, to colour: HighlightColour) {
        setColour(colour.colour, of: highlight)
    }

    /// The highlight under `point` on `page`, taking the one drawn on top where two overlap.
    ///
    /// The point is tested against the highlighted lines rather than the annotation's
    /// bounds. The bounds are one box around every line, and take in the blank space
    /// beside a first or last line that stops short.
    static func highlight(at point: CGPoint, on page: PDFPage) -> Highlight? {
        page.annotations
            .filter { $0.type == "Highlight" }
            .map { Highlight(annotation: $0, page: page) }
            .last { $0.lines.contains { $0.contains(point) } }
    }

    /// Changes a highlight's colour, and registers the old colour as undo.
    ///
    /// The highlight is taken off its page and put back around the change, because that
    /// is what makes the Read view redraw it.
    private func setColour(_ colour: NSColor, of highlight: Highlight) {
        let oldColour = highlight.annotation.color
        highlight.page.removeAnnotation(highlight.annotation)
        highlight.annotation.color = colour
        highlight.page.addAnnotation(highlight.annotation)

        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setColour(oldColour, of: highlight)
            }
        }
        undoManager?.setActionName("Change Highlight Colour")
    }

    /// Adds the highlights to their pages or takes them off, and registers the reverse as undo.
    ///
    /// Registering undo is also what marks the document as having unsaved changes. The
    /// page list is untouched, so `revision` is not bumped: the Read view redraws an
    /// annotated page by itself, and a bump would reload it and clear any search.
    private func setHighlights(_ highlights: [Highlight], shown: Bool, actionName: String) {
        for highlight in highlights {
            if shown {
                highlight.page.addAnnotation(highlight.annotation)
            } else {
                highlight.page.removeAnnotation(highlight.annotation)
            }
        }

        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setHighlights(highlights, shown: !shown, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
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
    /// has no folder, and finds nothing. Throws when the folder cannot be read.
    func similarlyNamedFiles() throws -> [URL] {
        guard let fileURL else { return [] }
        let base = fileURL.deletingPathExtension().lastPathComponent

        return try pdfsInFolder()
            .filter { url in
                let name = url.deletingPathExtension().lastPathComponent
                guard let match = name.range(of: base, options: [.anchored, .caseInsensitive]),
                      match.upperBound < name.endIndex
                else { return false }
                return Self.nameSeparators.contains(name[match.upperBound])
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// The naming pattern the other PDFs in this file's folder share, if they share one.
    /// Throws when the folder cannot be read.
    func namePattern() throws -> NamePattern? {
        guard let fileURL else { return nil }
        let names = try pdfsInFolder()
            .filter { $0.lastPathComponent != fileURL.lastPathComponent }
            .map { $0.deletingPathExtension().lastPathComponent }
        return NamePattern.find(in: names)
    }

    /// The PDFs in this file's folder, this one included.
    ///
    /// Throws rather than returning an empty list when the folder cannot be read. The two
    /// look the same otherwise, and macOS refusing access to the folder would pass for a
    /// folder with nothing in it.
    private func pdfsInFolder() throws -> [URL] {
        guard let fileURL else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(
            at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        return contents.filter { $0.pathExtension.lowercased() == "pdf" }
    }

    /// Adds every page of the PDFs at `files` to the end, saves, and moves them to the Trash.
    ///
    /// The pages arrive as one edit, in the order given, and nothing changes if any of the
    /// files cannot be read. The files are only trashed once the save has succeeded, so a
    /// failed save never leaves their pages existing nowhere on disk.
    ///
    /// Returns the files that could not be moved to the Trash.
    func mergeAndTrash(_ files: [URL]) async throws -> [URL] {
        guard let fileURL, let fileType else {
            throw CocoaError(.fileNoSuchFile)
        }
        let merged = try files.flatMap { try Self.copiedPages(of: $0) }
        applyPages(pageStates + merged, actionName: "Merge Similarly Named Files")
        try await save(to: fileURL, ofType: fileType, for: .saveOperation)

        var untrashed: [URL] = []
        for file in files {
            do {
                try FileManager.default.trashItem(at: file, resultingItemURL: nil)
            } catch {
                untrashed.append(file)
            }
        }
        return untrashed
    }

    /// Renames this document's file within its folder, keeping it a PDF.
    ///
    /// This goes through AppKit's `move(to:)` rather than a plain file move, so the
    /// document follows its file: the tab shows the new name, and the next save writes
    /// there. Unsaved edits stay unsaved.
    ///
    /// A name that is already taken is refused rather than replacing that file. Only a
    /// change of case in this file's own name gets past that check, because the Mac's
    /// file system sees `tiger.pdf` and `Tiger.pdf` as the same file.
    func rename(to name: String) async throws {
        guard let fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        var name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasSuffix(".pdf") {
            name = String(name.dropLast(4))
        }
        let destination = fileURL.deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension("pdf")

        guard !name.isEmpty, !name.contains("/"), !name.contains(":") else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSFilePathErrorKey: destination.path])
        }
        guard destination.lastPathComponent != fileURL.lastPathComponent else { return }
        if FileManager.default.fileExists(atPath: destination.path), !isSameFile(destination, fileURL) {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: destination.path])
        }
        try await move(to: destination)
    }

    private func isSameFile(_ a: URL, _ b: URL) -> Bool {
        let key = URLResourceKey.fileResourceIdentifierKey
        guard let first = try? a.resourceValues(forKeys: [key]).fileResourceIdentifier,
              let second = try? b.resourceValues(forKeys: [key]).fileResourceIdentifier
        else { return false }
        return first.isEqual(second)
    }
}
