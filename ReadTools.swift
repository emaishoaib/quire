//
//  ReadTools.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

/// The pill shape shared by every control floating over the document.
///
/// The fixed content height is what keeps the separate pills the same size as each other,
/// however tall their contents happen to be.
struct FloatingCapsule: ViewModifier {
    static let contentHeight = 26.0

    func body(content: Content) -> some View {
        content
            .frame(height: Self.contentHeight)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

extension View {
    func floatingCapsule() -> some View {
        modifier(FloatingCapsule())
    }
}

/// The tools that float below the search field, in the top-right of the document.
///
/// These live over the document rather than in the window's toolbar because SwiftUI
/// toolbars hosted in an AppKit window ignore trailing placement, which would strand
/// them at the far left, away from the search field they belong beside.
struct ReadTools: View {
    let viewer: ViewerController
    let ocr: OCRRunner
    let document: QuireDocument

    var body: some View {
        HStack(spacing: 8) {
            if !viewer.matches.isEmpty {
                HStack(spacing: 2) {
                    button("Previous Match", systemImage: "chevron.left") { viewer.previousMatch() }
                        .keyboardShortcut("g", modifiers: [.command, .shift])

                    Text("\(viewer.matchIndex + 1) of \(viewer.matches.count)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    button("Next Match", systemImage: "chevron.right") { viewer.nextMatch() }
                        .keyboardShortcut("g", modifiers: .command)
                }
                .floatingCapsule()
            }

            HStack(spacing: 2) {
                button("Recognize Text", systemImage: "text.viewfinder") {
                    ocr.run(on: document)
                }
                .disabled(document.pageCount == 0 || ocr.isRunning)

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 2)

                button("Zoom Out", systemImage: "minus.magnifyingglass") { viewer.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)

                button("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") { viewer.fitPage() }
                    .keyboardShortcut("0", modifiers: .command)

                button("Zoom In", systemImage: "plus.magnifyingglass") { viewer.zoomIn() }
                    .keyboardShortcut("=", modifiers: .command)
            }
            .floatingCapsule()
        }
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 30, height: 26)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
