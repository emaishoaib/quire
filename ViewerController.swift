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

    @ObservationIgnored private weak var view: PDFView?
    @ObservationIgnored private var lastQuery = ""
    @ObservationIgnored private var pendingPage: Int?
    @ObservationIgnored private var pageObserver: (any NSObjectProtocol)?

    /// Takes hold of a newly created view and restores what the old one was showing.
    ///
    /// Switching between Read and Pages destroys the view, so any scroll target or
    /// search highlight asked for while it was gone is applied here instead.
    func attach(_ view: PDFView) {
        self.view = view
        if !matches.isEmpty {
            view.highlightedSelections = matches
        }
        observePageChanges(of: view)
        goToPendingPage()
        showCurrentMatch()
    }

    /// Republishes PDFKit's page changes as observable state.
    ///
    /// `PDFView` tracks the page you are on privately and only posts a notification
    /// about it, so the page indicator has nothing to read without this.
    private func observePageChanges(of view: PDFView) {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
        }
        pageObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: view,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncCurrentPage()
            }
        }
        syncCurrentPage()
    }

    private func syncCurrentPage() {
        guard let view, let page = view.currentPage, let document = view.document else { return }
        currentPage = document.index(for: page)
    }

    func zoomIn() {
        view?.zoomIn(nil)
    }

    func zoomOut() {
        view?.zoomOut(nil)
    }

    /// Fits the page to the window, which is also how to recover from overshooting a pinch zoom.
    func zoomToFit() {
        view?.autoScales = true
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
