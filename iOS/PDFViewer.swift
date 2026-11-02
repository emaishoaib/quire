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
        view.onScroll = { [weak controller] in controller?.hideHighlightBar() }
        view.onScrollEnded = { [weak controller] in controller?.selectionDidChange() }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document !== pdf else { return }
        view.document = pdf
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let controller: ViewerController

        init(controller: ViewerController) {
            self.controller = controller
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            controller.hideHighlightBar()
            (recognizer.view as? PDFView)?.clearSelection()
            controller.pressEnded(at: recognizer.location(in: recognizer.view))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            !isOnHighlight(gestureRecognizer)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer is UITapGestureRecognizer && isOnHighlight(gestureRecognizer)
        }

        private func isOnHighlight(_ recognizer: UIGestureRecognizer) -> Bool {
            controller.highlight(at: recognizer.location(in: recognizer.view)) != nil
        }
    }
}

final class FittingPDFView: PDFView {
    private static let scrollEndDelay = Duration.milliseconds(150)

    var onFirstLayout: (() -> Void)?
    var onResize: ((PDFDestination?) -> Void)?
    var onScroll: (() -> Void)?
    var onScrollEnded: (() -> Void)?

    private var laidOutWidth: CGFloat = 0
    private var scrollObservation: NSKeyValueObservation?
    private var scrollEnd: Task<Void, Never>?

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
            observeScrolling()
        } else {
            onResize?(top)
        }
    }

    private func observeScrolling() {
        guard let scrollView = subviews.lazy.compactMap({ $0 as? UIScrollView }).first else { return }
        scrollObservation = scrollView.observe(\.contentOffset) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.didScroll()
            }
        }
    }

    private func didScroll() {
        onScroll?()
        scrollEnd?.cancel()
        guard currentSelection != nil else { return }
        scrollEnd = Task { [weak self] in
            try? await Task.sleep(for: Self.scrollEndDelay)
            guard !Task.isCancelled else { return }
            self?.onScrollEnded?()
        }
    }
}
