//
//  ViewerController.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// Drives the live `PDFView` on behalf of SwiftUI.
///
/// SwiftUI recreates the view wrapper freely, so the reference to the AppKit view
/// is held here instead, where it survives those rebuilds.
@Observable
final class ViewerController {

    /// How the rail's find control changes shape, and how the match count rolls over.
    ///
    /// The animation is applied where the values change rather than in the view: a view
    /// appearing or disappearing is not covered by `animation(_:value:)` on the view
    /// itself, so without this the swap happens instantly.
    static let searchAnimation = Animation.spring(duration: 0.32, bounce: 0.2)

    private(set) var matches: [PDFSelection] = []
    private(set) var matchIndex = 0
    private(set) var currentPage = 0
    private(set) var scale = 1.0
    private(set) var isTwoUp = false
    private(set) var isContinuous = true
    private(set) var showsCoverPage = false
    private(set) var attachCount = 0
    var matchCase = false

    @ObservationIgnored private weak var view: PDFView?
    @ObservationIgnored private var lastQuery = ""
    @ObservationIgnored private var pendingPage: Int?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var pulse: Task<Void, Never>?
    @ObservationIgnored private var snapshot: Snapshot?

    /// True from a document opening until the user first changes the zoom.
    ///
    /// The window is resized several times while it opens, first at its minimum size, so
    /// the opening fit to height is redone on each resize until the user takes over.
    @ObservationIgnored private var keepsHeightFitted = false

    /// The scale last set from code, to tell a pinch-zoom apart from a refit.
    @ObservationIgnored private var appliedScale: CGFloat = 1

    /// True while code is setting the scale.
    ///
    /// PDFKit posts its scale notification from inside the assignment, before
    /// `appliedScale` can be updated, so the pinch check has to sit that one out.
    @ObservationIgnored private var isApplyingScale = false

    /// What the Read view was showing when it was torn down, for the next one to pick up.
    private struct Snapshot {
        let scale: CGFloat
        let autoScales: Bool
        let destination: PDFDestination?
    }

    /// The live view, for the thumbnail sidebar to hand itself to.
    var attachedView: PDFView? { view }

    /// Takes hold of a newly created view and restores what the old one was showing.
    ///
    /// Switching between Read and Pages destroys the view. The page layout and search
    /// highlights are applied here. The zoom and scroll position wait for
    /// `viewDidFirstLayout`, because they need the view to have a size.
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

    /// Remembers what the view is showing before SwiftUI tears it down.
    func detach(_ view: PDFView) {
        guard view === self.view else { return }
        snapshot = Snapshot(
            scale: view.scaleFactor,
            autoScales: view.autoScales,
            destination: view.currentDestination
        )
    }

    /// Republishes PDFKit's page and zoom changes as observable state.
    ///
    /// `PDFView` tracks the current page and scale privately and only posts notifications
    /// about them, so the page indicator and the zoom percentage have nothing to read
    /// without this, and would go stale the moment the user scrolled or pinch-zoomed.
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
        syncFromView()
    }

    private func syncFromView() {
        guard let view else { return }
        if keepsHeightFitted && !isApplyingScale && view.scaleFactor != appliedScale {
            keepsHeightFitted = false
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

    /// Leaves the first page on its own, the way a book's cover sits alone.
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
        keepsHeightFitted = false
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

    /// Fits the whole page in the window, and keeps doing so as the window resizes.
    func fitPage() {
        keepsHeightFitted = false
        view?.autoScales = true
        syncFromView()
    }

    /// Fits the page's width to the window, which PDFKit has no built-in setting for.
    func fitWidth() {
        guard let size = displayedPageSize, let view, size.width > 0 else { return }
        setScale((view.bounds.width - 24) / size.width)
    }

    /// Sets the zoom and scroll position, once the view has a size to fit against.
    ///
    /// A fresh document is fitted to the window's height. A view rebuilt after visiting
    /// Pages goes back to where the old one was, unless a page was picked there.
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
            keepsHeightFitted = true
            applyHeightFit(keeping: view.currentDestination)
        }
        goToPendingPage()
    }

    /// Redoes the opening fit to height while the window is still settling.
    func viewDidResize(keeping top: PDFDestination?) {
        guard keepsHeightFitted else { return }
        applyHeightFit(keeping: top)
    }

    /// Fits the page's height to the window, the counterpart to `fitWidth`.
    func fitHeight() {
        keepsHeightFitted = false
        applyHeightFit(keeping: nil)
    }

    /// Fits the height, then scrolls `top` back to the top of the view if one is given.
    ///
    /// The page is fitted together with the gap PDFKit draws above and below it, which
    /// scales with the page. The page then fills the window and the next one starts
    /// exactly at the bottom edge, rather than showing a sliver of it.
    ///
    /// Changing the scale keeps PDFKit centred on roughly the same spot rather than on
    /// the top of the page, so without this the opening refits drift down the document.
    private func applyHeightFit(keeping top: PDFDestination?) {
        guard let size = displayedPageSize, let view, size.height > 0 else { return }
        let margins = view.pageBreakMargins
        let gap = view.displaysPageBreaks ? margins.top + margins.bottom : 0
        applyScale(view.bounds.height / (size.height + gap))
        if let top {
            view.go(to: top)
        }
    }

    /// The current page's size as shown, with width and height swapped for rotated pages.
    private var displayedPageSize: CGSize? {
        guard let view, let page = view.currentPage else { return nil }
        let bounds = page.bounds(for: view.displayBox)
        return page.rotation % 180 == 0
            ? bounds.size
            : CGSize(width: bounds.height, height: bounds.width)
    }

    func zoomIn() {
        keepsHeightFitted = false
        view?.zoomIn(nil)
        syncFromView()
    }

    func zoomOut() {
        keepsHeightFitted = false
        view?.zoomOut(nil)
        syncFromView()
    }

    func previousPage() {
        view?.goToPreviousPage(nil)
    }

    func nextPage() {
        view?.goToNextPage(nil)
    }

    /// Scrolls to a page, or remembers it until the view comes back.
    func goToPage(_ index: Int) {
        pendingPage = index
        goToPendingPage()
    }

    private func goToPendingPage() {
        guard let view, let pendingPage, let page = view.document?.page(at: pendingPage) else { return }
        view.go(to: page)
        self.pendingPage = nil
    }

    /// Runs a search, replacing any results already on screen.
    ///
    /// Typing re-runs this on every keystroke, so it always starts from the first match
    /// rather than advancing, which is what `submitSearch` does when the query is unchanged.
    func search(_ query: String, in pdf: PDFDocument) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        lastQuery = query
        let found = pdf.findString(query, withOptions: matchCase ? [] : .caseInsensitive)
        for match in found {
            match.color = .systemYellow
        }
        withAnimation(Self.searchAnimation) {
            matches = found
            matchIndex = 0
        }
        view?.highlightedSelections = found.isEmpty ? nil : found
        showCurrentMatch()
    }

    /// The matched text grouped by what it actually says, with how often each form occurs.
    ///
    /// A case-insensitive search for "delivery" can match "Delivery" and "delivery", and
    /// the results list names each form rather than pretending they were identical.
    var matchGroups: [(text: String, count: Int, firstIndex: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var first: [String: Int] = [:]

        for (index, match) in matches.enumerated() {
            let text = match.string ?? ""
            guard !text.isEmpty else { continue }
            if counts[text] == nil {
                order.append(text)
                first[text] = index
            }
            counts[text, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0, first[$0] ?? 0) }
    }

    func goToMatch(_ index: Int) {
        guard matches.indices.contains(index) else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = index
        }
        showCurrentMatch()
    }

    /// Searches for `query`, or advances to the next match when the query is unchanged.
    func submitSearch(_ query: String, in pdf: PDFDocument) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            clearSearch()
            return
        }
        guard query != lastQuery || matches.isEmpty else {
            nextMatch()
            return
        }

        lastQuery = query
        matches = pdf.findString(query, withOptions: matchCase ? [] : .caseInsensitive)
        for match in matches {
            match.color = .systemYellow
        }
        matchIndex = 0
        view?.highlightedSelections = matches.isEmpty ? nil : matches
        showCurrentMatch()
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = (matchIndex + 1) % matches.count
        }
        showCurrentMatch()
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        withAnimation(Self.searchAnimation) {
            matchIndex = (matchIndex - 1 + matches.count) % matches.count
        }
        showCurrentMatch()
    }

    func clearSearch() {
        pulse?.cancel()
        lastQuery = ""
        withAnimation(Self.searchAnimation) {
            matches = []
            matchIndex = 0
        }
        view?.highlightedSelections = nil
        view?.clearSelection()
    }

    /// Scrolls to the current match and flashes it.
    ///
    /// Every match is highlighted the same yellow, so landing on one is otherwise silent.
    /// The current match is drawn in a second colour, and flashes brighter for a moment
    /// when it is reached, which is what makes the jump visible on a crowded page.
    private func showCurrentMatch() {
        guard matches.indices.contains(matchIndex), let view else { return }
        let match = matches[matchIndex]

        view.setCurrentSelection(match, animate: true)
        view.go(to: match)

        pulse?.cancel()
        pulse = Task { [weak self] in
            for colour in [NSColor.systemOrange, .systemOrange.withAlphaComponent(0.75), .systemPink] {
                guard !Task.isCancelled else { return }
                self?.paint(match, colour)
                try? await Task.sleep(for: .milliseconds(110))
            }
            guard !Task.isCancelled else { return }
            self?.paint(match, .systemPink)
        }
    }

    /// Repaints one match and hands the highlights back to the view to redraw them.
    private func paint(_ match: PDFSelection, _ colour: NSColor) {
        for other in matches where other !== match {
            other.color = .systemYellow
        }
        match.color = colour
        view?.highlightedSelections = matches
    }
}
