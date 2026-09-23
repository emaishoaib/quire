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
        view.onResize = { [weak controller] in controller?.viewDidResize() }
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
///
/// The view has no size when it is created, so anything that fits the page to the
/// window has to wait until here. The window also keeps changing size while it opens,
/// so an opening fit has to follow those changes too.
final class FittingPDFView: PDFView {
    var onFirstLayout: (() -> Void)?
    var onResize: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        guard newSize != oldSize, newSize.height > 0 else { return }
        onResize?()
    }

    override func layout() {
        super.layout()
        guard bounds.height > 0, let action = onFirstLayout else { return }
        onFirstLayout = nil
        action()
    }
}
