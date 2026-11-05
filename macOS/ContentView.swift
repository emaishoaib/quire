import PDFKit
import SwiftUI

struct ContentView: View {
    private static let thumbnailWidth = 220.0

    let document: QuireDocument

    @State private var viewer: ViewerController
    @State private var ocr = OCRRunner()
    @State private var showsFind = false
    @State private var findRequests = 0
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("highlightColour") private var highlightColour = HighlightColour.yellow
    @State private var sidebarTab: SidebarTab

    private var model: PDFModel { document.model }

    init(document: QuireDocument) {
        self.document = document
        _viewer = State(initialValue: ViewerController(
            openingPosition: document.fileURL.flatMap(ReadingPositions.position)
        ))
        _sidebarTab = State(initialValue: SidebarTab.opening(document.model.pdf))
    }

    var body: some View {
        Group {
            if model.pdf.pageCount == 0 {
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
                                pdf: model.pdf,
                                revision: model.revision,
                                controller: viewer,
                                removeHighlight: model.removeHighlight
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
                            PageGrid(model: model, selection: $selection, currentPage: viewer.currentPage) { index in
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
                        model: model,
                        find: openFind,
                        mode: $mode,
                        showsThumbnails: $showsThumbnails
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
            viewer.highlight(in: highlightColour, of: model)
        }
        .onChange(of: model.revision) {
            viewer.clearSearch()
            selection = selection.filter { $0 < model.pageCount }
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
            SidebarTabSwitch(selection: $sidebarTab)
                .padding(10)

            Divider()

            Group {
                switch sidebarTab {
                case .thumbnails:
                    ThumbnailSidebar(
                        model: model,
                        viewer: viewer,
                        thumbnailWidth: Self.thumbnailWidth
                    )
                case .contents:
                    ContentsSidebar(model: model, viewer: viewer)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: ThumbnailSidebar.sidebarWidth(for: Self.thumbnailWidth))
        .background(Color(nsColor: .underPageBackgroundColor))
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
                        viewer.highlight(in: colour, of: model)
                    },
                    remove: hasRemove ? { viewer.removeSelectedHighlight(from: model) } : nil
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
                FindBar(viewer: viewer, pdf: model.pdf, focusRequests: findRequests, isPresented: $showsFind)
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
