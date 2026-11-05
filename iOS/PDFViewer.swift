import PDFKit
import SwiftUI

struct PDFViewer: UIViewRepresentable {
    let pdf: PDFDocument
    let revision: Int
    let controller: ViewerController
    let onEdgeDrag: (CGFloat) -> Void
    let onEdgeDragEnded: (CGFloat) -> Void
    var onScroll: () -> Void = {}
    var isHighlighting = false

    func makeCoordinator() -> Coordinator {
        Coordinator(revision: revision, controller: controller)
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
        view.onScroll = { [weak controller, weak coordinator = context.coordinator] in
            controller?.hideHighlightBar()
            coordinator?.onScroll?()
        }
        view.onScrollEnded = { [weak controller] in controller?.selectionDidChange() }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let highlightDrag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.highlightDragged))
        highlightDrag.maximumNumberOfTouches = 1
        highlightDrag.delegate = context.coordinator
        highlightDrag.allowedTouchTypes = Coordinator.touchTypes(highlighting: false)
        view.addGestureRecognizer(highlightDrag)
        context.coordinator.highlightDrag = highlightDrag

        let edgeDrag = UIScreenEdgePanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.edgeDragged))
        edgeDrag.edges = .left
        view.addGestureRecognizer(edgeDrag)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.onEdgeDrag = onEdgeDrag
        context.coordinator.onEdgeDragEnded = onEdgeDragEnded
        context.coordinator.onScroll = onScroll
        context.coordinator.setHighlighting(isHighlighting, in: view)
        let pagesChanged = context.coordinator.revision != revision
        guard view.document !== pdf || pagesChanged else { return }
        context.coordinator.revision = revision

        let currentPage = view.currentPage.flatMap { view.document?.index(for: $0) } ?? 0
        view.document = pdf
        if let page = pdf.page(at: min(currentPage, max(pdf.pageCount - 1, 0))) {
            view.go(to: page)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var revision: Int
        let controller: ViewerController
        var onEdgeDrag: ((CGFloat) -> Void)?
        var onEdgeDragEnded: ((CGFloat) -> Void)?
        var onScroll: (() -> Void)?
        weak var highlightDrag: UIPanGestureRecognizer?
        private var dragStart: CGPoint?
        private var isHighlighting = false

        static func touchTypes(highlighting: Bool) -> [NSNumber] {
            let types: [UITouch.TouchType] = highlighting ? [.direct, .pencil] : [.pencil]
            return types.map { NSNumber(value: $0.rawValue) }
        }

        init(revision: Int, controller: ViewerController) {
            self.revision = revision
            self.controller = controller
        }

        @objc func edgeDragged(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            let distance = recognizer.translation(in: recognizer.view).x
            switch recognizer.state {
            case .began, .changed:
                onEdgeDrag?(distance)
            case .ended:
                onEdgeDragEnded?(distance)
            case .cancelled, .failed:
                onEdgeDragEnded?(0)
            default:
                break
            }
        }

        func setHighlighting(_ highlighting: Bool, in view: PDFView) {
            guard isHighlighting != highlighting else { return }
            isHighlighting = highlighting
            highlightDrag?.allowedTouchTypes = Self.touchTypes(highlighting: highlighting)
            (view as? FittingPDFView)?.scrollView?.panGestureRecognizer.minimumNumberOfTouches = highlighting ? 2 : 1
        }

        @objc func highlightDragged(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view as? PDFView, let document = view.document else { return }
            let point = recognizer.location(in: view)
            switch recognizer.state {
            case .began:
                let moved = recognizer.translation(in: view)
                dragStart = CGPoint(x: point.x - moved.x, y: point.y - moved.y)
                controller.isDraggingHighlight = true
                controller.hideHighlightBar()
            case .changed:
                guard let start = dragStart,
                      let startPage = view.page(for: start, nearest: true),
                      let endPage = view.page(for: point, nearest: true)
                else { return }
                view.currentSelection = document.selection(
                    from: startPage,
                    at: view.convert(start, to: startPage),
                    to: endPage,
                    at: view.convert(point, to: endPage)
                )
            case .ended:
                dragStart = nil
                controller.isDraggingHighlight = false
                if view.currentSelection != nil {
                    controller.highlightRequests += 1
                }
            case .cancelled, .failed:
                dragStart = nil
                controller.isDraggingHighlight = false
                view.clearSelection()
            default:
                break
            }
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
            guard gestureRecognizer !== highlightDrag else { return false }
            return !isOnHighlight(gestureRecognizer)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer !== highlightDrag else { return false }
            return otherGestureRecognizer is UITapGestureRecognizer && isOnHighlight(gestureRecognizer)
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

    override func go(to destination: PDFDestination) {
        super.go(to: destination)
        guard let page = destination.page, destination.point.y != kPDFDestinationUnspecifiedValue,
              let scrollView else { return }
        scrollView.contentOffset.y += convert(destination.point, from: page).y
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
        guard let scrollView else { return }
        let fingers: [UITouch.TouchType] = [.direct, .indirect, .indirectPointer]
        scrollView.panGestureRecognizer.allowedTouchTypes = fingers.map { NSNumber(value: $0.rawValue) }
        scrollObservation = scrollView.observe(\.contentOffset) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.didScroll()
            }
        }
    }

    var scrollView: UIScrollView? {
        subviews.lazy.compactMap { $0 as? UIScrollView }.first
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
