//
//  PDFViewer.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// Shows a PDF using PDFKit's own view, which brings scrolling, zooming,
/// page breaks and text selection with it.
///
/// A document opens with its first page fitted to the window's height.
struct PDFViewer: NSViewRepresentable {
    let pdf: PDFDocument
    let revision: Int
    let controller: ViewerController
    let removeHighlight: (Highlight) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(revision: revision, controller: controller)
    }

    /// Hands the view's zoom and position to the controller as SwiftUI removes it.
    static func dismantleNSView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.controller.detach(view)
    }

    func makeNSView(context: Context) -> PDFView {
        let view = FittingPDFView()
        view.autoScales = false
        view.scaleFactor = 1
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        view.document = pdf
        controller.attach(view)
        view.onFirstLayout = { [weak controller] in controller?.viewDidFirstLayout() }
        view.onResize = { [weak controller] top in controller?.viewDidResize(keeping: top) }
        view.onMouseDown = { [weak controller] in controller?.mouseWentDown() }
        view.onMouseUp = { [weak controller] in controller?.mouseWentUp(at: $0) }
        view.showsHighlighterCursor = { [weak controller] in controller?.isHighlighting ?? false }
        view.onContextClick = { [weak controller, removeHighlight] point in
            guard let highlight = controller?.highlightToRemove(at: point) else { return false }
            removeHighlight(highlight)
            return true
        }
        return view
    }

    /// Reloads only when the document object or its page list has actually changed.
    ///
    /// SwiftUI calls this on every state change, and assigning `document` scrolls the
    /// view back to the first page, so a reload restores the page you were on.
    func updateNSView(_ view: PDFView, context: Context) {
        let pagesChanged = context.coordinator.revision != revision
        guard view.document !== pdf || pagesChanged else { return }
        context.coordinator.revision = revision

        let currentPage = view.currentPage.flatMap { view.document?.index(for: $0) } ?? 0
        view.document = pdf
        if let page = pdf.page(at: min(currentPage, max(pdf.pageCount - 1, 0))) {
            view.go(to: page)
        }
    }

    /// Remembers the page list the view was last loaded with, and which controller drives it.
    final class Coordinator {
        var revision: Int
        let controller: ViewerController

        init(revision: Int, controller: ViewerController) {
            self.revision = revision
            self.controller = controller
        }
    }
}

/// A `PDFView` that reports its first layout with a real size, and every resize after.
/// It also reports the mouse being pressed and released over it, swaps its cursor for a
/// highlighter when asked to, and offers right clicks to its owner before opening a menu.
///
/// The view has no size when it is created, so anything that fits the page to the
/// window has to wait until here. The window also keeps changing size while it opens,
/// so an opening fit has to follow those changes too.
final class FittingPDFView: PDFView {
    var onFirstLayout: (() -> Void)?
    var onResize: ((PDFDestination?) -> Void)?
    var onMouseDown: (() -> Void)?
    var onMouseUp: ((NSPoint) -> Void)?
    var showsHighlighterCursor: (() -> Bool)?

    /// Offered each right click or Control-click, with where in this view it landed.
    /// Returning true means the click has been dealt with, and no menu should open.
    var onContextClick: ((NSPoint) -> Bool)?

    private var dealtWithClick: TimeInterval?

    /// Reports the new size along with the spot that was at the top before the resize.
    ///
    /// Resizing moves the scroll position by itself, so the spot is read before `super`
    /// applies the new size, while it is still the one the user was looking at.
    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        let top = currentDestination
        super.setFrameSize(newSize)
        guard newSize != oldSize, newSize.height > 0 else { return }
        onResize?(top)
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    /// Reports the release, and where in this view it happened.
    ///
    /// PDFKit sees the release first, so the selection is the finished one.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?(convert(event.locationInWindow, from: nil))
    }

    /// Offers the click to `onContextClick` before letting PDFKit open its menu.
    ///
    /// PDFKit asks for the menu twice for one right click, once from the page under the
    /// mouse and once from this view. The click is offered the first time only, and the
    /// second is answered the same way without asking. Offered twice, a click on two
    /// highlights lying one over the other would remove both.
    override func menu(for event: NSEvent) -> NSMenu? {
        if dealtWithClick == event.timestamp {
            return nil
        }
        if onContextClick?(convert(event.locationInWindow, from: nil)) == true {
            dealtWithClick = event.timestamp
            return nil
        }
        return super.menu(for: event)
    }

    /// Shows the highlighter in place of whatever cursor PDFKit would have picked.
    ///
    /// PDFKit calls this each time the mouse moves, to switch between the arrow, the text
    /// cursor and the pointing hand. Setting a cursor any other way lasts only until the
    /// next move.
    override func setCursorFor(_ area: PDFAreaOfInterest) {
        if showsHighlighterCursor?() == true {
            NSCursor.highlighter.set()
        } else {
            super.setCursorFor(area)
        }
    }

    override func layout() {
        super.layout()
        guard bounds.height > 0, let action = onFirstLayout else { return }
        onFirstLayout = nil
        action()
    }
}

extension NSCursor {
    /// A highlighter pen, which points with its tip.
    ///
    /// The pen is drawn in black over a white copy of itself nudged in every direction,
    /// which gives it an outline. The system's own cursors are outlined the same way, so
    /// that they show on dark pages as well as light ones.
    static let highlighter: NSCursor = {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        func pen(in colour: NSColor) -> NSImage? {
            NSImage(systemSymbolName: "highlighter", accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration.applying(.init(paletteColors: [colour])))
        }
        guard let outline = pen(in: .white), let fill = pen(in: .black) else { return .iBeam }

        let inset = 2.0
        let size = NSSize(width: fill.size.width + inset * 2, height: fill.size.height + inset * 2)
        let image = NSImage(size: size, flipped: false) { _ in
            for x in [-1.0, 0, 1] {
                for y in [-1.0, 0, 1] where x != 0 || y != 0 {
                    outline.draw(at: NSPoint(x: inset + x, y: inset + y), from: .zero, operation: .sourceOver, fraction: 1)
                }
            }
            fill.draw(at: NSPoint(x: inset, y: inset), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 5, y: size.height - 7))
    }()
}
