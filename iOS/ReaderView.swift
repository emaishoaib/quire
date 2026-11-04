import SwiftUI

struct OpenedPDF: Identifiable {
    let id = UUID()
    let name: String
    let file: PDFFile
}

struct ReaderView: View {
    private static let thumbnailWidth = 170.0
    private static let sidebarWidth = 280.0
    private static let sidebarDismissDistance = 16.0

    let pdf: OpenedPDF

    @State private var controller = ViewerController()
    @State private var mode: Mode = .read
    @State private var sidebarTab: SidebarTab
    @State private var showsSidebar = false
    @State private var sidebarDrag = 0.0
    @State private var showsFind = false
    @State private var findRequests = 0
    @AppStorage("highlightColour") private var highlightColour = HighlightColour.yellow
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    private var model: PDFModel { pdf.file.model }

    private var hasRoomForRail: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    init(pdf: OpenedPDF) {
        self.pdf = pdf
        _sidebarTab = State(initialValue: SidebarTab.opening(pdf.file.model.pdf))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    content
                        .ignoresSafeArea(edges: .bottom)

                    if hasRoomForRail {
                        Divider()

                        ReadRail(
                            viewer: controller,
                            pageCount: model.pageCount,
                            find: openFind,
                            mode: $mode,
                            showsSidebar: $showsSidebar,
                            sidebarTab: $sidebarTab
                        )
                    }
                }

                if !hasRoomForRail {
                    Divider()

                    ReadBar(
                        viewer: controller,
                        pageCount: model.pageCount,
                        find: openFind,
                        mode: $mode,
                        showsSidebar: $showsSidebar
                    )
                }
            }
            .background(Color(.secondarySystemBackground), ignoresSafeAreaEdges: [.bottom, .horizontal])
            .animation(ThumbnailSidebar.animation, value: showsSidebar)
            .animation(ThumbnailSidebar.animation, value: sidebarTab)
            .navigationTitle(pdf.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: close)
                }
            }
        }
        .onChange(of: model.revision) {
            controller.clearSearch()
        }
        .sheet(isPresented: showingSidebarSheet) {
            SidebarSheet(
                model: model,
                viewer: controller,
                thumbnailWidth: Self.thumbnailWidth,
                tab: $sidebarTab
            )
        }
        .alert("Couldn't Save the PDF", isPresented: showingFailure) {
            Button("OK", action: acknowledgeFailure)
        } message: {
            Text(pdf.file.failure?.localizedDescription ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .read:
            PDFViewer(
                pdf: model.pdf,
                revision: model.revision,
                controller: controller,
                onEdgeDrag: edgeDragged,
                onEdgeDragEnded: edgeDragEnded
            )
            .overlay { highlightBar }
            .overlay(alignment: .topTrailing) { findPanel }
            .overlay(alignment: .leading) { slidingSidebar }
            .transition(.opacity.combined(with: .scale(scale: 1.02)))
        case .pages:
            PageGrid(model: model, currentPage: controller.currentPage) { index in
                withAnimation(Mode.animation) {
                    mode = .read
                }
                controller.goToPage(index)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var sidebarOffset: Double {
        showsSidebar
            ? min(sidebarDrag, 0)
            : min(sidebarDrag, Self.sidebarWidth) - Self.sidebarWidth
    }

    private var slidingSidebar: some View {
        ZStack(alignment: .leading) {
            if hasRoomForRail && (showsSidebar || sidebarDrag > 0) {
                Color.black
                    .opacity(0.25 * (1 + sidebarOffset / Self.sidebarWidth))
                    .contentShape(.rect)
                    .onTapGesture { showsSidebar = false }
                    .transition(.opacity)

                sidebar
                    .offset(x: sidebarOffset)
                    .simultaneousGesture(dismissingDrag)
                    .transition(.move(edge: .leading))
            }
        }
    }

    private var sidebar: some View {
        Group {
            switch sidebarTab {
            case .thumbnails:
                ThumbnailSidebar(model: model, viewer: controller, thumbnailWidth: Self.thumbnailWidth)
            case .contents:
                ContentsSidebar(model: model, viewer: controller)
            }
        }
        .frame(width: Self.sidebarWidth)
        .clipped()
        .background(Color(.secondarySystemBackground), ignoresSafeAreaEdges: .bottom)
        .shadow(color: .black.opacity(0.3), radius: 12)
    }

    private var dismissingDrag: some Gesture {
        DragGesture(minimumDistance: Self.sidebarDismissDistance)
            .onChanged { drag in
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                sidebarDrag = min(drag.translation.width, 0)
            }
            .onEnded { _ in
                withAnimation(ThumbnailSidebar.animation) {
                    showsSidebar = sidebarDrag > -Self.sidebarWidth / 3
                    sidebarDrag = 0
                }
            }
    }

    private func edgeDragged(_ distance: CGFloat) {
        guard hasRoomForRail, !showsSidebar else { return }
        sidebarDrag = max(distance, 0)
    }

    private func edgeDragEnded(_ distance: CGFloat) {
        guard hasRoomForRail, !showsSidebar else { return }
        withAnimation(ThumbnailSidebar.animation) {
            showsSidebar = distance > Self.sidebarWidth / 3
            sidebarDrag = 0
        }
    }

    private var findPanel: some View {
        VStack {
            if showsFind {
                FindBar(viewer: controller, pdf: model.pdf, focusRequests: findRequests, isPresented: $showsFind)
                    .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .padding(16)
    }

    private var highlightBar: some View {
        GeometryReader { proxy in
            if let anchor = controller.selectionAnchor {
                let hasRemove = controller.selectedHighlight != nil
                let centre = HighlightBar.centre(for: anchor, in: proxy.size, hasRemove: hasRemove)
                let origin = UnitPoint(
                    x: centre.x / max(proxy.size.width, 1),
                    y: centre.y / max(proxy.size.height, 1)
                )
                HighlightBar(
                    lastUsed: highlightColour,
                    pick: { colour in
                        highlightColour = colour
                        controller.highlight(in: colour, of: model)
                    },
                    remove: hasRemove ? { controller.removeSelectedHighlight(from: model) } : nil
                )
                .position(centre)
                .transition(.scale(scale: 0.85, anchor: origin).combined(with: .opacity))
            }
        }
    }

    private var showingSidebarSheet: Binding<Bool> {
        Binding(
            get: { !hasRoomForRail && showsSidebar },
            set: { showsSidebar = $0 }
        )
    }

    private var showingFailure: Binding<Bool> {
        Binding(
            get: { pdf.file.failure != nil },
            set: { _ in }
        )
    }

    private func openFind() {
        findRequests += 1
        withAnimation(Mode.animation) {
            mode = .read
        }
        withAnimation(FindBar.animation) {
            showsFind = true
        }
    }

    private func close() {
        Task {
            await pdf.file.closeFile()
            if pdf.file.failure == nil {
                dismiss()
            }
        }
    }

    private func acknowledgeFailure() {
        pdf.file.clearFailure()
        if pdf.file.documentState.contains(.closed) {
            dismiss()
        }
    }
}
