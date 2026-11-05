import PDFKit
import UIKit

extension FittingPDFView {
    func showHighlightPreview(of selection: PDFSelection?, in colour: HighlightColour) {
        let path = UIBezierPath()
        for line in selection?.selectionsByLine() ?? [] {
            for page in line.pages {
                let rect = line.bounds(for: page)
                guard !rect.isEmpty else { continue }
                path.append(UIBezierPath(rect: convert(rect, from: page)))
            }
        }
        drawHighlightPreview(path.cgPath, in: colour.colour.cgColor)
    }

    func clearHighlightPreview() {
        drawHighlightPreview(nil, in: nil)
    }

    private func drawHighlightPreview(_ path: CGPath?, in colour: CGColor?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightPreview.path = path
        highlightPreview.fillColor = colour
        CATransaction.commit()
    }
}
