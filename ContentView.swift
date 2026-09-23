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

    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                switch mode {
                case .read:
                    PDFViewer(pdf: document.pdf, revision: document.revision, controller: viewer)
                        .overlay(alignment: .bottomTrailing) {
                            ZoomControl(viewer: viewer)
                                .padding(16)
                        }
                        .overlay(alignment: .trailing) {
                            ZoomHUD(viewer: viewer)
                                .padding(.trailing, 16)
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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    ocr.run(on: document, undoManager: undoManager)
                } label: {
                    Label("Recognize Text", systemImage: "text.viewfinder")
                }
                .help("Make scanned pages searchable")
                .disabled(document.pageCount == 0 || ocr.isRunning)
            }

            if mode == .read {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        viewer.previousPage()
                    } label: {
                        Label("Previous Page", systemImage: "chevron.up")
                    }
                    .keyboardShortcut(.upArrow, modifiers: .command)

                    Button {
                        viewer.nextPage()
                    } label: {
                        Label("Next Page", systemImage: "chevron.down")
                    }
                    .keyboardShortcut(.downArrow, modifiers: .command)

                    Text("\(viewer.currentPage + 1) / \(document.pageCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                ToolbarItemGroup {
                    Button {
                        viewer.zoomOut()
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    .keyboardShortcut("-", modifiers: .command)

                    Button {
                        viewer.fitPage()
                    } label: {
                        Label("Zoom to Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                    .keyboardShortcut("0", modifiers: .command)

                    Button {
                        viewer.zoomIn()
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    .keyboardShortcut("=", modifiers: .command)
                }
            }

            if !viewer.matches.isEmpty {
                ToolbarItemGroup {
                    Button {
                        viewer.previousMatch()
                    } label: {
                        Label("Previous Match", systemImage: "chevron.left")
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])

                    Text("\(viewer.matchIndex + 1) of \(viewer.matches.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Button {
                        viewer.nextMatch()
                    } label: {
                        Label("Next Match", systemImage: "chevron.right")
                    }
                    .keyboardShortcut("g", modifiers: .command)
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
