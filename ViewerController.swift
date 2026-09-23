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

    private(set) var matches: [PDFSelection] = []
    private(set) var matchIndex = 0
    private(set) var currentPage = 0
    private(set) var scale = 1.0
    private(set) var isTwoUp = false
    private(set) var isContinuous = true
    private(set) var showsCoverPage = false

    @ObservationIgnored private weak var view: PDFView?
    @ObservationIgnored private var lastQuery = ""
    @ObservationIgnored private var pendingPage: Int?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    /// Takes hold of a newly created view and restores what the old one was showing.
    ///
    /// Switching between Read and Pages destroys the view, so any scroll target or
    /// search highlight asked for while it was gone is applied here instead.
    func attach(_ view: PDFView) {
        self.view = view
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
        matches = pdf.findString(query, withOptions: .caseInsensitive)
        for match in matches {
            match.color = .systemYellow
        }
        matchIndex = 0
        view?.highlightedSelections = matches.isEmpty ? nil : matches
        showCurrentMatch()
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        matchIndex = (matchIndex + 1) % matches.count
        showCurrentMatch()
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        matchIndex = (matchIndex - 1 + matches.count) % matches.count
        showCurrentMatch()
    }

    func clearSearch() {
        lastQuery = ""
        matches = []
        matchIndex = 0
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
