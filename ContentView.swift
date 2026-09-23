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
}

/// The window's contents: the open PDF, or an empty state for a document with no pages.
struct ContentView: View {
    @Bindable var document: QuireDocument

    @State private var viewer = ViewerController()
    @State private var ocr = OCRRunner()
    @State private var query = ""
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()
    @AppStorage("showsThumbnails") private var showsThumbnails = true
    @AppStorage("thumbnailWidth") private var thumbnailWidth = 120.0

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                switch mode {
                case .read:
                    HStack(spacing: 0) {
                        if showsThumbnails {
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
                            .animation(.easeOut(duration: 0.12), value: thumbnailWidth)

                            Divider()
                        }

                        PDFViewer(pdf: document.pdf, revision: document.revision, controller: viewer)
                            .overlay(alignment: .trailing) {
                                ZoomHUD(viewer: viewer)
                                    .padding(.trailing, 16)
                            }

                        Divider()

                        ReadRail(viewer: viewer, ocr: ocr, document: document)
                    }
                case .pages:
                    PageGrid(document: document, selection: $selection) { index in
                        mode = .read
                        viewer.goToPage(index)
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .onSubmit(of: .search) {
            mode = .read
            viewer.submitSearch(query, in: document.pdf)
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                viewer.clearSearch()
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if mode == .read {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showsThumbnails.toggle()
                    } label: {
                        Label("Thumbnails", systemImage: "sidebar.left")
                    }
                    .help("Show or hide page thumbnails")
                    .keyboardShortcut("t", modifiers: [.command, .option])
                }

            }

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
