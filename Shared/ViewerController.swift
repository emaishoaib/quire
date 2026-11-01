import PDFKit
import SwiftUI

@MainActor
@Observable
final class ViewerController {
    static let searchAnimation = Animation.spring(duration: 0.32, bounce: 0.2)

    var matches: [PDFSelection] = []
    var matchIndex = 0
    private(set) var currentPage = 0
    private(set) var scale = 1.0
    private(set) var isTwoUp = false
    private(set) var isContinuous = true
    private(set) var showsCoverPage = false
    private(set) var attachCount = 0

    var isHighlighting = false

    var highlightRequests = 0

    var selectionAnchor: SelectionAnchor?

    var selectedHighlight: Highlight?
    var matchCase = false

    @ObservationIgnored weak var view: PDFView?
    @ObservationIgnored var lastQuery = ""
    @ObservationIgnored private var pendingPage: Int?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored var pulse: Task<Void, Never>?
    @ObservationIgnored private var snapshot: Snapshot?

    @ObservationIgnored private var openingPosition: ReadingPosition?

    @ObservationIgnored private var keepsHeightFitted = false

    @ObservationIgnored private var keepsOpeningSpot = false

    @ObservationIgnored private var appliedScale: CGFloat = 1

    @ObservationIgnored private var isApplyingScale = false

    @ObservationIgnored var followsSelection = false

    private struct Snapshot {
        let scale: CGFloat
        let autoScales: Bool
        let destination: PDFDestination?
    }

    init(openingPosition: ReadingPosition? = nil) {
        self.openingPosition = openingPosition
    }

    var attachedView: PDFView? { view }

    var position: ReadingPosition? {
        if let openingPosition {
            return openingPosition
        }
        guard let destination = snapshot?.destination ?? view?.currentDestination else { return nil }
        let scale = keepsHeightFitted ? nil : snapshot?.scale ?? view?.scaleFactor
        return ReadingPosition(destination, scale: scale.map(Double.init))
    }

    private func zoomWasChosen() {
        keepsHeightFitted = false
        keepsOpeningSpot = false
    }

    func attach(_ view: PDFView) {
        self.view = view
        attachCount += 1
        applyDisplayMode()
        view.displaysAsBook = showsCoverPage
        if !matches.isEmpty {
            view.highlightedSelections = matches
        }
        observeChanges(of: view)
    }

    func detach(_ view: PDFView) {
        guard view === self.view else { return }
        snapshot = Snapshot(
            scale: view.scaleFactor,
            autoScales: view.autoScales,
            destination: view.currentDestination
        )
        hideHighlightBar()
    }

    private func observeChanges(of view: PDFView) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = [.PDFViewPageChanged, .PDFViewScaleChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.syncFromView()
                }
            }
        }
        observers += [Notification.Name.PDFViewScaleChanged, .PDFViewDisplayModeChanged].map { name in
            NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.hideHighlightBar()
                }
            }
        }
        observers.append(
            NotificationCenter.default.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.selectionDidChange()
                }
            }
        )
        syncFromView()
    }

    private func syncFromView() {
        guard let view else { return }
        if !isApplyingScale && view.scaleFactor != appliedScale {
            zoomWasChosen()
        }
        if let page = view.currentPage, let document = view.document {
            currentPage = document.index(for: page)
        }
        scale = view.scaleFactor
        isTwoUp = view.displayMode == .twoUp || view.displayMode == .twoUpContinuous
        isContinuous = view.displayMode == .singlePageContinuous || view.displayMode == .twoUpContinuous
        showsCoverPage = view.displaysAsBook
    }

    func setTwoUp(_ twoUp: Bool) {
        isTwoUp = twoUp
        applyDisplayMode()
    }

    func setContinuous(_ continuous: Bool) {
        isContinuous = continuous
        applyDisplayMode()
    }

    func setShowsCoverPage(_ showsCover: Bool) {
        showsCoverPage = showsCover
        view?.displaysAsBook = showsCover
    }

    private func applyDisplayMode() {
        guard let view else { return }
        view.displayMode = switch (isTwoUp, isContinuous) {
        case (false, false): .singlePage
        case (false, true): .singlePageContinuous
        case (true, false): .twoUp
        case (true, true): .twoUpContinuous
        }
    }

    func setScale(_ factor: Double) {
        zoomWasChosen()
        applyScale(factor)
    }

    private func applyScale(_ factor: Double) {
        guard let view else { return }
        view.autoScales = false
        isApplyingScale = true
        view.scaleFactor = factor
        isApplyingScale = false
        appliedScale = view.scaleFactor
        syncFromView()
    }

    func fitPage() {
        zoomWasChosen()
        view?.autoScales = true
        syncFromView()
    }

    func fitWidth() {
        guard let size = displayedPageSize, let view, size.width > 0 else { return }
        setScale((view.bounds.width - 24) / size.width)
    }

    func viewDidFirstLayout() {
        guard let view else { return }
        if let snapshot {
            self.snapshot = nil
            if snapshot.autoScales {
                view.autoScales = true
            } else {
                setScale(snapshot.scale)
            }
            if let destination = snapshot.destination {
                view.go(to: destination)
            }
        } else {
            let opening = view.document.flatMap { openingPosition?.destination(in: $0) }
            let openingScale = openingPosition?.scale
            openingPosition = nil
            if let opening, let openingScale {
                setScale(openingScale)
                keepsOpeningSpot = true
                view.go(to: opening)
            } else {
                keepsHeightFitted = true
                applyHeightFit(keeping: opening ?? view.currentDestination)
            }
        }
        goToPendingPage()
    }

    func viewDidResize(keeping top: PDFDestination?) {
        hideHighlightBar()
        if keepsHeightFitted {
            applyHeightFit(keeping: top)
        } else if keepsOpeningSpot, let top {
            view?.go(to: top)
        }
    }

    func fitHeight() {
        zoomWasChosen()
        applyHeightFit(keeping: nil)
    }

    private func applyHeightFit(keeping top: PDFDestination?) {
        guard let size = displayedPageSize, let view, size.height > 0 else { return }
        let margins = view.pageBreakMargins
        let gap = view.displaysPageBreaks ? margins.top + margins.bottom : 0
        applyScale(view.bounds.height / (size.height + gap))
        if let top {
            view.go(to: top)
        }
    }

    private var displayedPageSize: CGSize? {
        guard let view, let page = view.currentPage else { return nil }
        let bounds = page.bounds(for: view.displayBox)
        return page.rotation % 180 == 0
            ? bounds.size
            : CGSize(width: bounds.height, height: bounds.width)
    }

    func zoomIn() {
        zoomWasChosen()
        view?.zoomIn(nil)
        syncFromView()
    }

    func zoomOut() {
        zoomWasChosen()
        view?.zoomOut(nil)
        syncFromView()
    }

    func previousPage() {
        view?.goToPreviousPage(nil)
    }

    func nextPage() {
        view?.goToNextPage(nil)
    }

    func goToPage(_ index: Int) {
        pendingPage = index
        goToPendingPage()
    }

    func go(to destination: PDFDestination) {
        view?.go(to: destination)
    }

    private func goToPendingPage() {
        guard let view, let pendingPage, let page = view.document?.page(at: pendingPage) else { return }
        view.go(to: page)
        self.pendingPage = nil
    }
}
