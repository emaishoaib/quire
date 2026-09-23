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

    /// Takes hold of a newly created view and restores what the old one was showing.
    ///
    /// Switching between Read and Pages destroys the view, so any scroll target or
    /// search highlight asked for while it was gone is applied here instead.
    /// The live view, for the thumbnail sidebar to hand itself to.
    var attachedView: PDFView? { view }

    func attach(_ view: PDFView) {
        self.view = view
        attachCount += 1
        if !matches.isEmpty {
            view.highlightedSelections = matches
        }
        observeChanges(of: view)
        goToPendingPage()
        showCurrentMatch()
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
        guard let view else { return }
        view.autoScales = false
        view.scaleFactor = factor
        syncFromView()
    }

    /// Fits the whole page in the window, and keeps doing so as the window resizes.
    func fitPage() {
        view?.autoScales = true
        syncFromView()
    }

    /// Fits the page's width to the window, which PDFKit has no built-in setting for.
    func fitWidth() {
        guard let size = displayedPageSize, let view, size.width > 0 else { return }
        setScale((view.bounds.width - 24) / size.width)
    }

    /// Fits the page's height to the window, the counterpart to `fitWidth`.
    func fitHeight() {
        guard let size = displayedPageSize, let view, size.height > 0 else { return }
        setScale((view.bounds.height - 24) / size.height)
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
        view?.zoomIn(nil)
        syncFromView()
    }

    func zoomOut() {
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
        lastQuery = ""
        withAnimation(Self.searchAnimation) {
            matches = []
            matchIndex = 0
        }
        view?.highlightedSelections = nil
        view?.clearSelection()
    }

    private func showCurrentMatch() {
        guard matches.indices.contains(matchIndex), let view else { return }
        let match = matches[matchIndex]
        view.setCurrentSelection(match, animate: true)
        view.go(to: match)
    }
}
