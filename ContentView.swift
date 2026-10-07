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
    @State private var findRequests = 0
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0
    @AppStorage("highlightColour") private var highlightColour = HighlightColour.yellow
    @State private var sidebarTab: SidebarTab

    /// Opens on the table of contents when the PDF has one, and on thumbnails otherwise.
    ///
    /// The tab is chosen here rather than when the view appears, so the window opens
    /// on it instead of animating over to it. It belongs to this window rather than
    /// being a setting, because each PDF gets its own starting tab.
    init(document: QuireDocument) {
        _document = Bindable(document)
        _sidebarTab = State(initialValue: SidebarTab.opening(document.pdf))
    }

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                HStack(spacing: 0) {
                    if mode == .read && showsThumbnails {
                        sidebar
                            .transition(.move(edge: .leading).combined(with: .opacity))

                        Divider()
                            .transition(.opacity)
                    }

                    Group {
                        switch mode {
                        case .read:
                            PDFViewer(pdf: document.pdf, revision: document.revision, controller: viewer)
                                .overlay(alignment: .trailing) {
                                    ZoomHUD(viewer: viewer)
                                        .padding(.trailing, 16)
                                }
                                .overlay {
                                    highlightBar
                                }
                                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        case .pages:
                            PageGrid(document: document, selection: $selection, currentPage: viewer.currentPage) { index in
                                withAnimation(Mode.animation) {
                                    mode = .read
                                }
                                viewer.goToPage(index)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        findPanel
                    }

                    Divider()

                    ReadRail(
                        viewer: viewer,
                        ocr: ocr,
                        document: document,
                        find: openFind,
                        mode: $mode,
                        showsThumbnails: $showsThumbnails,
                        sidebarTab: $sidebarTab
                    )
                }
                .animation(ThumbnailSidebar.animation, value: showsThumbnails)
                .animation(ThumbnailSidebar.animation, value: sidebarTab)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background {
            Button("Find") {
                withAnimation(Mode.animation) {
                    mode = .read
                }
                openFind()
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
        .onChange(of: viewer.highlightRequests) {
            viewer.highlight(in: highlightColour, of: document)
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

    /// The sidebar beside the document in Read mode, showing thumbnails or contents.
    ///
    /// The rail switches between the two. The switch is animated from the container
    /// holding both the sidebar and the rail, keyed to the tab, so the rail's icon
    /// animates along with the sidebar.
    ///
    /// Both tabs share one width, set by the size slider beneath them, so switching tabs
    /// leaves the document where it is.
    private var sidebar: some View {
        VStack(spacing: 0) {
            Group {
                switch sidebarTab {
                case .thumbnails:
                    ThumbnailSidebar(
                        document: document,
                        viewer: viewer,
                        thumbnailWidth: thumbnailWidth
                    )
                case .contents:
                    ContentsSidebar(document: document, viewer: viewer)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            ThumbnailSizeControl(thumbnailWidth: $thumbnailWidth)
        }
        .frame(width: ThumbnailSidebar.sidebarWidth(for: thumbnailWidth))
        .background(Color(nsColor: .underPageBackgroundColor))
        .animation(ThumbnailSidebar.sizeAnimation, value: thumbnailWidth)
    }

    /// The highlight bar, placed beside the selected text or the clicked highlight.
    ///
    /// It grows out of its own centre as it appears. The transition is told where that is,
    /// because the view it applies to is the whole overlay rather than the bar alone.
    private var highlightBar: some View {
        GeometryReader { proxy in
            if let anchor = viewer.selectionAnchor {
                let hasRemove = viewer.selectedHighlight != nil
                let centre = HighlightBar.centre(for: anchor, in: proxy.size, hasRemove: hasRemove)
                let origin = UnitPoint(
                    x: centre.x / max(proxy.size.width, 1),
                    y: centre.y / max(proxy.size.height, 1)
                )
                HighlightBar(
                    lastUsed: highlightColour,
                    pick: { colour in
                        highlightColour = colour
                        viewer.highlight(in: colour, of: document)
                    },
                    remove: hasRemove ? { viewer.removeSelectedHighlight(from: document) } : nil
                )
                    .position(centre)
                    .transition(.scale(scale: 0.85, anchor: origin).combined(with: .opacity))
            }
        }
    }

    /// Opens the find panel, or puts the cursor back in its field when it is already open.
    ///
    /// The count is what the panel watches: asking for a panel that is already showing
    /// changes nothing else, so without it a second Cmd-F would go unnoticed.
    private func openFind() {
        findRequests += 1
        withAnimation(FindBar.animation) {
            showsFind = true
        }
    }

    /// The Find panel, in the top-right corner of the document while reading.
    ///
    /// The padding is on a container around the panel rather than on the panel, so the
    /// panel grows out of its own corner as it appears, not out of the padding's.
    private var findPanel: some View {
        VStack {
            if mode == .read && showsFind {
                FindBar(viewer: viewer, pdf: document.pdf, focusRequests: findRequests, isPresented: $showsFind)
                    .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .padding(16)
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
