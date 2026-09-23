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
    @State private var query = ""
    @State private var mode: Mode = .read
    @State private var selection = Set<Int>()

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                switch mode {
                case .read:
                    PDFViewer(pdf: document.pdf, controller: viewer)
                case .pages:
                    PageGrid(pdf: document.pdf, selection: $selection) { index in
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
}

#Preview {
    ContentView(document: QuireDocument())
}
