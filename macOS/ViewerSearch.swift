import PDFKit
import SwiftUI

extension ViewerController {
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

    private func showCurrentMatch() {
        guard matches.indices.contains(matchIndex), let view else { return }
        let match = matches[matchIndex]

        hideHighlightBar()
        view.setCurrentSelection(match, animate: true)
        view.go(to: match)

        pulse?.cancel()
        pulse = Task { [weak self] in
            for colour in [PlatformColor.systemOrange, .systemOrange.withAlphaComponent(0.75), .systemPink] {
                guard !Task.isCancelled else { return }
                self?.paint(match, colour)
                try? await Task.sleep(for: .milliseconds(110))
            }
            guard !Task.isCancelled else { return }
            self?.paint(match, .systemPink)
        }
    }

    private func paint(_ match: PDFSelection, _ colour: PlatformColor) {
        for other in matches where other !== match {
            other.color = .systemYellow
        }
        match.color = colour
        view?.highlightedSelections = matches
    }
}
