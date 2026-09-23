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
    let controller: ViewerController

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

    /// Reassigns the document only when it is a different one.
    ///
    /// SwiftUI calls this on every state change, and setting `document` scrolls
    /// the view back to the first page.
    func updateNSView(_ view: PDFView, context: Context) {
        guard view.document !== pdf else { return }
        view.document = pdf
    }
}
