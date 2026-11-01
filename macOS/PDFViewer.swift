import PDFKit
import SwiftUI

struct PDFViewer: NSViewRepresentable {
    let pdf: PDFDocument
    let revision: Int
    let controller: ViewerController
    let removeHighlight: (Highlight) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(revision: revision, controller: controller)
    }

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
        view.onMouseDown = { [weak controller] in controller?.hideHighlightBar() }
        view.onMouseUp = { [weak controller] in controller?.pressEnded(at: $0) }
        view.onScroll = { [weak controller] in controller?.hideHighlightBar() }
        view.onContextClick = { [weak controller, removeHighlight] point in
            guard let highlight = controller?.highlightToRemove(at: point) else { return false }
            removeHighlight(highlight)
            return true
        }
        return view
    }

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

    final class Coordinator {
        var revision: Int
        let controller: ViewerController

        init(revision: Int, controller: ViewerController) {
            self.revision = revision
            self.controller = controller
        }
    }
}

final class FittingPDFView: PDFView {
    var onFirstLayout: (() -> Void)?
    var onResize: ((PDFDestination?) -> Void)?
    var onMouseDown: (() -> Void)?
    var onMouseUp: ((NSPoint) -> Void)?
    var onScroll: (() -> Void)?

    var onContextClick: ((NSPoint) -> Bool)?

    private var dealtWithClick: TimeInterval?

    override init(frame: NSRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("FittingPDFView is only made in code")
    }

    @objc private func clipViewDidScroll(_ notification: Notification) {
        guard let scrolled = notification.object as? NSClipView, scrolled.isDescendant(of: self) else { return }
        onScroll?()
    }

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

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?(convert(event.locationInWindow, from: nil))
    }

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

    override func layout() {
        super.layout()
        guard bounds.height > 0, let action = onFirstLayout else { return }
        onFirstLayout = nil
        action()
    }
}
