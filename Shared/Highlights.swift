import AppKit
import PDFKit

struct Highlight {
    let annotation: PDFAnnotation
    let page: PDFPage

    var isOnPage: Bool { annotation.page === page }

    var lines: [CGRect] {
        let origin = annotation.bounds.origin
        let corners = (annotation.quadrilateralPoints ?? []).map(\.pointValue)
        let lines = stride(from: 0, to: corners.count - 3, by: 4).map { start in
            let line = corners[start..<start + 4]
            let xs = line.map(\.x)
            let ys = line.map(\.y)
            return CGRect(
                x: origin.x + (xs.min() ?? 0),
                y: origin.y + (ys.min() ?? 0),
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
        }
        return lines.isEmpty ? [annotation.bounds] : lines
    }
}

extension PDFModel {
    func highlight(_ selection: PDFSelection, in colour: HighlightColour) {
        var linesByPage: [(page: PDFPage, lines: [CGRect])] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let rect = line.bounds(for: page)
                guard !rect.isEmpty else { continue }
                if let index = linesByPage.firstIndex(where: { $0.page === page }) {
                    linesByPage[index].lines.append(rect)
                } else {
                    linesByPage.append((page, [rect]))
                }
            }
        }

        let highlights = linesByPage.map { page, lines in
            let bounds = lines.dropFirst().reduce(lines[0]) { $0.union($1) }
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = colour.colour
            annotation.quadrilateralPoints = lines.flatMap { line in
                [
                    NSPoint(x: line.minX - bounds.minX, y: line.maxY - bounds.minY),
                    NSPoint(x: line.maxX - bounds.minX, y: line.maxY - bounds.minY),
                    NSPoint(x: line.minX - bounds.minX, y: line.minY - bounds.minY),
                    NSPoint(x: line.maxX - bounds.minX, y: line.minY - bounds.minY)
                ].map { NSValue(point: $0) }
            }
            return Highlight(annotation: annotation, page: page)
        }
        guard !highlights.isEmpty else { return }
        setHighlights(highlights, shown: true, actionName: "Highlight")
    }

    func removeHighlight(_ highlight: Highlight) {
        setHighlights([highlight], shown: false, actionName: "Remove Highlight")
    }

    func recolourHighlight(_ highlight: Highlight, to colour: HighlightColour) {
        setColour(colour.colour, of: highlight)
    }

    static func highlight(at point: CGPoint, on page: PDFPage) -> Highlight? {
        page.annotations
            .filter { $0.type == "Highlight" }
            .map { Highlight(annotation: $0, page: page) }
            .last { $0.lines.contains { $0.contains(point) } }
    }

    private func setColour(_ colour: NSColor, of highlight: Highlight) {
        let oldColour = highlight.annotation.color
        highlight.page.removeAnnotation(highlight.annotation)
        highlight.annotation.color = colour
        highlight.page.addAnnotation(highlight.annotation)

        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.setColour(oldColour, of: highlight)
            }
        }
        undoManager?.setActionName("Change Highlight Colour")
    }

    private func setHighlights(_ highlights: [Highlight], shown: Bool, actionName: String) {
        for highlight in highlights {
            if shown {
                highlight.page.addAnnotation(highlight.annotation)
            } else {
                highlight.page.removeAnnotation(highlight.annotation)
            }
        }

        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.setHighlights(highlights, shown: !shown, actionName: actionName)
            }
        }
        undoManager?.setActionName(actionName)
    }
}
