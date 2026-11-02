import PDFKit
import SwiftUI

enum Mode: String, CaseIterable, Identifiable {
    case read = "Read"
    case pages = "Pages"

    var id: Self { self }

    static let animation = Animation.spring(duration: 0.32, bounce: 0.1)
}

struct ContentView: View {
    @Bindable var document: QuireDocument

    @State private var viewer: ViewerController
    @State private var ocr = OCRRunner()
    @State private var showsFind = false
    @State private var findRequests = 0
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0
    @AppStorage("highlightColour") private var highlightColour = HighlightColour.yellow
    @State private var sidebarTab: SidebarTab

    init(document: QuireDocument) {
        _document = Bindable(document)
        _viewer = State(initialValue: ViewerController(
            openingPosition: document.fileURL.flatMap(ReadingPositions.position)
        ))
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
                            PDFViewer(
                                pdf: document.pdf,
                                revision: document.revision,
                                controller: viewer,
                                removeHighlight: document.removeHighlight
                            )
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
                .overlayPreferenceValue(HighlightButtonKey.self) { button in
                    highlightPalette(beside: button)
                }
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
        .onAppear {
            document.viewer = viewer
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

    private func highlightPalette(beside button: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if viewer.isHighlighting, let button {
                let size = HighlightPalette.size
                let source = proxy[button]
                let centre = CGPoint(
                    x: proxy.size.width - ReadRail.width - 9 - size.width / 2,
                    y: min(max(source.midY, size.height / 2 + 8), proxy.size.height - size.height / 2 - 8)
                )
                let origin = UnitPoint(
                    x: source.midX / max(proxy.size.width, 1),
                    y: source.midY / max(proxy.size.height, 1)
                )
                HighlightPalette(selected: $highlightColour)
                    .position(centre)
                    .transition(.scale(scale: 0.3, anchor: origin).combined(with: .opacity))
            }
        }
    }

    private func openFind() {
        findRequests += 1
        withAnimation(FindBar.animation) {
            showsFind = true
        }
    }

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
