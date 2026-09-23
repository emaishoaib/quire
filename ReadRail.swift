//
//  ReadRail.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

/// The narrow column of controls down the right edge of the Read view.
///
/// Document actions sit at the top and view controls at the bottom, so the things that
/// change the file and the things that change how you look at it stay apart.
///
/// Only the page number is drawn as a field, because it is the only value here that can
/// be typed into. The zoom percentage is plain text with chevrons, which say it opens a
/// menu without suggesting it can be edited.
struct ReadRail: View {
    let viewer: ViewerController
    let ocr: OCRRunner
    let document: QuireDocument
    @Binding var showsFind: Bool

    private let width = 62.0

    var body: some View {
        VStack(spacing: 8) {
            button("Find", systemImage: "magnifyingglass") { showsFind = true }

            button("Recognize text: make scanned pages searchable", systemImage: "text.viewfinder") {
                ocr.run(on: document)
            }
            .disabled(document.pageCount == 0 || ocr.isRunning)

            Spacer(minLength: 20)

            PageIndicator(viewer: viewer, pageCount: document.pageCount)

            separator

            VStack(spacing: 0) {
                indicator("chevron.up")

                Menu {
                    Button("Fit Page") { viewer.fitPage() }
                    Button("Fit Width") { viewer.fitWidth() }
                    Button("Fit Height") { viewer.fitHeight() }
                    Divider()
                    ForEach([0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4], id: \.self) { preset in
                        Button(ZoomControl.percentage(preset)) { viewer.setScale(preset) }
                    }
                } label: {
                    Text(ZoomControl.percentage(viewer.scale))
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 22)
                .help("Zoom level and fit options")

                indicator("chevron.down")
            }

            button("Actual Size", systemImage: "1.magnifyingglass") { viewer.setScale(1) }

            button("Zoom In", systemImage: "plus.magnifyingglass") { viewer.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)

            button("Zoom Out", systemImage: "minus.magnifyingglass") { viewer.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(width: width)
        .background(.bar)
    }

    private var separator: some View {
        Divider()
            .frame(width: 26)
    }

    /// The chevrons above and below the zoom percentage.
    ///
    /// They sit outside the menu rather than inside its label: the borderless menu style
    /// rewrites whatever label it is given, which dropped one chevron and the pill
    /// background. Their job is to say the percentage opens a list of zoom levels.
    private func indicator(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(height: 10)
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .frame(width: 34, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
