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

    @ObservationIgnored private weak var view: PDFView?
    @ObservationIgnored private var lastQuery = ""

    func attach(_ view: PDFView) {
        self.view = view
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
