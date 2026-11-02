import PDFKit
import SwiftUI

struct PDFViewer: UIViewRepresentable {
    let pdf: PDFDocument
    let controller: ViewerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.controller.detach(view)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = FittingPDFView()
        view.autoScales = false
        view.scaleFactor = 1
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .secondarySystemBackground
        view.document = pdf
        controller.attach(view)
        view.onFirstLayout = { [weak controller] in controller?.viewDidFirstLayout() }
        view.onResize = { [weak controller] top in controller?.viewDidResize(keeping: top) }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document !== pdf else { return }
        view.document = pdf
    }

    final class Coordinator {
        let controller: ViewerController

        init(controller: ViewerController) {
            self.controller = controller
        }
    }
}

final class FittingPDFView: PDFView {
    var onFirstLayout: (() -> Void)?
    var onResize: ((PDFDestination?) -> Void)?

    private var laidOutWidth: CGFloat = 0

    override var currentDestination: PDFDestination? {
        let corner = CGPoint(x: bounds.minX, y: bounds.minY)
        guard let page = page(for: corner, nearest: true) else { return nil }
        return PDFDestination(page: page, at: convert(corner, to: page))
    }

    override func layoutSubviews() {
        let top = currentDestination
        super.layoutSubviews()
        guard bounds.height > 0, bounds.width != laidOutWidth else { return }
        laidOutWidth = bounds.width

        if let action = onFirstLayout {
            onFirstLayout = nil
            action()
        } else {
            onResize?(top)
        }
    }
}
