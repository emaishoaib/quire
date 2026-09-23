//
//  ContentView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// Which half of the app the window is showing.
enum Mode: String, CaseIterable, Identifiable {
    case read = "Read"
    case pages = "Pages"

    var id: Self { self }

    /// How the window changes between reading and organising.
    ///
    /// Applied wherever the mode is set rather than in the views, because a view being
    /// swapped for another cannot animate its own arrival.
    static let animation = Animation.spring(duration: 0.32, bounce: 0.1)
}

/// The window's contents: the open PDF, or an empty state for a document with no pages.
struct ContentView: View {
    @Bindable var document: QuireDocument

    @State private var viewer = ViewerController()
    @State private var ocr = OCRRunner()
    @State private var showsFind = false
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                HStack(spacing: 0) {
                    if mode == .read && showsThumbnails {
                        VStack(spacing: 0) {
                            ThumbnailSidebar(
                                document: document,
                                viewer: viewer,
                                thumbnailWidth: thumbnailWidth
                            )

                            Divider()

                            ThumbnailSizeControl(thumbnailWidth: $thumbnailWidth)
                        }
                        .frame(width: ThumbnailSidebar.sidebarWidth(for: thumbnailWidth))
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .animation(ThumbnailSidebar.sizeAnimation, value: thumbnailWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                        Divider()
                            .transition(.opacity)
                    }

                    switch mode {
                    case .read:
                        PDFViewer(pdf: document.pdf, revision: document.revision, controller: viewer)
                            .overlay(alignment: .topTrailing) {
                                if showsFind {
                                    FindBar(viewer: viewer, pdf: document.pdf, isPresented: $showsFind)
                                        .padding(16)
                                        .transition(
                                            .scale(scale: 0.85, anchor: .topTrailing)
                                                .combined(with: .opacity)
                                        )
                                }
                            }
                            .overlay(alignment: .trailing) {
                                ZoomHUD(viewer: viewer)
                                    .padding(.trailing, 16)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    case .pages:
                        PageGrid(document: document, selection: $selection) { index in
                            withAnimation(Mode.animation) {
                                mode = .read
                            }
                            viewer.goToPage(index)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    Divider()

                    ReadRail(
                        viewer: viewer,
                        ocr: ocr,
                        document: document,
                        showsFind: $showsFind,
                        mode: $mode,
                        showsThumbnails: $showsThumbnails
                    )
                }
                .animation(ThumbnailSidebar.animation, value: showsThumbnails)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background {
            Button("Find") {
                withAnimation(Mode.animation) {
                    mode = .read
                }
                withAnimation(FindBar.animation) {
                    showsFind = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        }
        .onChange(of: viewer.matches.isEmpty) { _, isEmpty in
            if !isEmpty {
                withAnimation(FindBar.animation) {
                    showsFind = true
                }
            }
        }
        .onChange(of: document.revision) {
            viewer.clearSearch()
            selection = selection.filter { $0 < document.pageCount }
        }
        .sheet(isPresented: $ocr.isRunning) {
            OCRProgressView(ocr: ocr)
        }
        .alert("Recognize Text", isPresented: showingSummary) {
            Button("OK") {}
        } message: {
            Text(ocr.summary ?? "")
        }
    }

    private var showingSummary: Binding<Bool> {
        Binding(
            get: { ocr.summary != nil },
            set: { if !$0 { ocr.summary = nil } }
        )
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
