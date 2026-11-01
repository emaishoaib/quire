import PDFKit
import SwiftUI

extension ViewerController {
    func mouseWentDown() {
        hideHighlightBar()
    }

    func setHighlighting(_ highlighting: Bool) {
        isHighlighting = highlighting
        if highlighting {
            hideHighlightBar()
        }
    }

    func mouseWentUp(at point: NSPoint) {
        guard !isHighlighting else {
            if view?.currentSelection != nil {
                highlightRequests += 1
            }
            return
        }
        followsSelection = true
        placeHighlightBar()
        guard selectionAnchor == nil,
              let view,
              let highlight = highlight(at: point),
              let anchor = anchor(of: highlight.lines, on: highlight.page, in: view)
        else { return }
        withAnimation(HighlightBar.animation) {
            selectedHighlight = highlight
            selectionAnchor = anchor
        }
    }

    func highlightToRemove(at point: NSPoint) -> Highlight? {
        isHighlighting ? highlight(at: point) : nil
    }

    private func highlight(at point: NSPoint) -> Highlight? {
        guard let view, let page = view.page(for: point, nearest: false) else { return nil }
        return PDFModel.highlight(at: view.convert(point, to: page), on: page)
    }

    func hideHighlightBar() {
        followsSelection = false
        guard selectionAnchor != nil else { return }
        withAnimation(HighlightBar.animation) {
            selectionAnchor = nil
            selectedHighlight = nil
        }
    }

    func highlight(in colour: HighlightColour, of model: PDFModel) {
        if let highlight = selectedHighlight {
            if highlight.isOnPage {
                model.recolourHighlight(highlight, to: colour)
            }
            hideHighlightBar()
            return
        }
        guard let view, let selection = view.currentSelection else { return }
        model.highlight(selection, in: colour)
        hideHighlightBar()
        view.clearSelection()
    }

    func removeSelectedHighlight(from model: PDFModel) {
        if let highlight = selectedHighlight, highlight.isOnPage {
            model.removeHighlight(highlight)
        }
        hideHighlightBar()
    }

    func selectionDidChange() {
        guard followsSelection else { return }
        placeHighlightBar()
    }

    func viewDidScroll(_ scrolled: NSClipView?) {
        guard let view, let scrolled, scrolled.isDescendant(of: view) else { return }
        hideHighlightBar()
    }

    private func placeHighlightBar() {
        let anchor = currentSelectionAnchor
        guard anchor != nil || (selectionAnchor != nil && selectedHighlight == nil) else { return }
        withAnimation(HighlightBar.animation) {
            selectionAnchor = anchor
            selectedHighlight = nil
        }
    }

    private var currentSelectionAnchor: SelectionAnchor? {
        guard let view,
              let lines = view.currentSelection?.selectionsByLine(),
              let first = lines.first,
              let last = lines.last,
              let firstPage = first.pages.first,
              let lastPage = last.pages.last,
              let top = anchor(of: [first.bounds(for: firstPage)], on: firstPage, in: view),
              let bottom = anchor(of: [last.bounds(for: lastPage)], on: lastPage, in: view)
        else { return nil }
        return SelectionAnchor(firstLine: top.firstLine, lastLine: bottom.lastLine)
    }

    private func anchor(of lines: [CGRect], on page: PDFPage, in view: PDFView) -> SelectionAnchor? {
        let rects = lines
            .map { view.convert($0, from: page) }
            .filter { !$0.isEmpty }
            .map { rect in
                view.isFlipped
                    ? rect
                    : CGRect(x: rect.minX, y: view.bounds.height - rect.maxY, width: rect.width, height: rect.height)
            }
        guard let first = rects.min(by: { $0.minY < $1.minY }),
              let last = rects.max(by: { $0.maxY < $1.maxY })
        else { return nil }
        return SelectionAnchor(firstLine: first, lastLine: last)
    }
}
