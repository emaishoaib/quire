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
struct PDFViewer: NSViewRepresentable {
    let pdf: PDFDocument
    let revision: Int
    let controller: ViewerController

    func makeCoordinator() -> Coordinator {
        Coordinator(revision: revision)
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        view.document = pdf
        controller.attach(view)
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

    /// Remembers the page list the view was last loaded with.
    final class Coordinator {
        var revision: Int

        init(revision: Int) {
            self.revision = revision
        }
    }
}
