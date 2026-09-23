//
//  OCRRunner.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import CoreGraphics
import CoreText
import PDFKit
import SwiftUI

/// Runs the OCR engine over a document and reports what it is doing.
///
/// Recognition happens off the main actor, one page at a time, so the window stays
/// usable and the run can be cancelled between pages. The whole run is applied as a
/// single edit, so one press of Cmd-Z puts the document back.
@Observable
final class OCRRunner {

    var isRunning = false
    private(set) var progress = 0.0
    private(set) var status = ""
    var summary: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Pages holding at least this much text already are left alone.
    @ObservationIgnored private static let existingTextThreshold = 20

    /// False until Vision has recognised something in this run of the app.
    @ObservationIgnored private static var isVisionReady = false

    /// Loads Vision's model in the background at launch.
    ///
    /// The first recognition after a restart can take up to a minute while macOS
    /// prepares the model, and doing it here means the user rarely waits for it.
    static func warmUp() {
        Task {
            await recognizeSample()
            isVisionReady = true
        }
    }

    private nonisolated static func recognizeSample() async {
        guard let context = CGContext(
            data: nil,
            width: 400,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 100))

        let font = CTFontCreateWithName("Helvetica" as CFString, 48, nil)
        let sample = NSAttributedString(
            string: "Warm up",
            attributes: [.init(kCTFontAttributeName as String): font]
        )
        context.textPosition = CGPoint(x: 20, y: 30)
        CTLineDraw(CTLineCreateWithAttributedString(sample), context)

        guard let image = context.makeImage() else { return }
        _ = try? await OCREngine.recognizeWords(in: image, rotation: 0)
    }

    func run(on document: QuireDocument) {
        guard !isRunning else { return }

        let original = document.pageStates
        let total = original.count
        guard total > 0 else { return }

        isRunning = true
        progress = 0
        status = Self.isVisionReady ? "Starting…" : Self.preparingMessage

        task = Task {
            var replacements: [Int: PDFPage] = [:]
            var skipped = 0

            for (index, item) in original.enumerated() {
                if Task.isCancelled { break }
                status = Self.isVisionReady ? "Page \(index + 1) of \(total)" : Self.preparingMessage

                let existing = item.page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if existing.count >= Self.existingTextThreshold {
                    skipped += 1
                } else if let pageRef = item.page.pageRef {
                    let data = try? await OCREngine.searchablePage(from: pageRef, rotation: item.rotation)
                    Self.isVisionReady = true
                    if let data, let page = Self.makePage(from: data, like: item.page) {
                        replacements[index] = page
                    }
                }
                progress = Double(index + 1) / Double(total)
            }

            isRunning = false
            finish(replacements: replacements, skipped: skipped, of: original, on: document)
        }
    }

    func cancel() {
        task?.cancel()
    }

    private func finish(
        replacements: [Int: PDFPage],
        skipped: Int,
        of original: [PageState],
        on document: QuireDocument
    ) {
        if Task.isCancelled {
            summary = "Text recognition was cancelled, so no pages were changed."
            return
        }
        guard !replacements.isEmpty else {
            summary = skipped == original.count
                ? "Every page already has text, so there was nothing to recognise."
                : "No text was found on the pages that needed it."
            return
        }

        let newState = original.enumerated().map { index, item in
            replacements[index].map { PageState(page: $0, rotation: item.rotation) } ?? item
        }
        document.applyPages(newState, actionName: "Recognize Text")

        let count = replacements.count
        var message = "Made \(count) page\(count == 1 ? "" : "s") searchable."
        if skipped > 0 {
            message += " \(skipped) already had text and were left alone."
        }
        summary = message
    }

    /// Turns the engine's one-page PDF into a page carrying the original's crop and annotations.
    private static func makePage(from data: Data, like original: PDFPage) -> PDFPage? {
        guard let page = PDFDocument(data: data)?.page(at: 0)?.copy() as? PDFPage else { return nil }
        page.setBounds(original.bounds(for: .cropBox), for: .cropBox)

        for annotation in original.annotations {
            if let copy = annotation.copy() as? PDFAnnotation {
                page.addAnnotation(copy)
            }
        }
        return page
    }

    private static let preparingMessage = "Preparing text recognition… This can take up to a minute the first time."
}

/// The sheet shown while a document is being recognised.
struct OCRProgressView: View {
    @Bindable var ocr: OCRRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognizing text…")
                .font(.headline)

            ProgressView(value: ocr.progress)

            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(ocr.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { ocr.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .interactiveDismissDisabled()
    }
}
