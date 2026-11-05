import SwiftUI
import UIKit

enum WelcomePDF {
    private static let offeredKey = "hasOfferedWelcomePDF"
    private static let fileName = "Welcome to Quire.pdf"
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin = 56.0
    private static let wordmarkHeight = 56.0

    static func createIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: offeredKey) else { return }
        defaults.set(true, forKey: offeredKey)

        let folder = URL.documentsDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        guard contents.isEmpty else { return }
        try? pdf().write(to: folder.appending(path: fileName))
    }

    private static func pdf() -> Data {
        UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(page)

            let band = CGRect(x: 0, y: 0, width: page.width, height: margin * 2 + wordmarkHeight)
            UIColor(Color.wine).setFill()
            context.fill(band)

            let renderer = ImageRenderer(content: Wordmark(height: wordmarkHeight))
            renderer.scale = 3
            renderer.uiImage?.draw(at: CGPoint(x: margin, y: margin))

            let textArea = CGRect(
                x: margin,
                y: band.maxY + 48,
                width: page.width - margin * 2,
                height: page.height - band.maxY - 48 - margin
            )
            text.draw(in: textArea)
        }
    }

    private static var text: NSAttributedString {
        let place = UIDevice.current.userInterfaceIdiom == .pad ? "On My iPad" : "On My iPhone"
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let wine = UIColor(Color.wine)

        let title = NSAttributedString(string: "Welcome to Quire\n", attributes: [
            .font: UIFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: wine,
            .paragraphStyle: spacing(after: 18)
        ])
        let body = NSAttributedString(string: """
            Quire's library shows the PDFs kept in its own folder on this \(device). To add yours:
            1.  Open the Files app.
            2.  Go to \(place), then Quire.
            3.  Move or copy your PDFs into it. Folders work too.
            4.  Back in Quire, pull down on the library to refresh it.
            Once your own files are here, you can delete this one.
            """, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(white: 0.15, alpha: 1),
            .paragraphStyle: spacing(after: 12)
        ])

        let text = NSMutableAttributedString(attributedString: title)
        text.append(body)
        return text
    }

    private static func spacing(after: Double) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = after
        style.lineSpacing = 4
        return style
    }
}
