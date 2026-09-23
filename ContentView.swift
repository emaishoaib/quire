//
//  ContentView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// The window's contents: the open PDF, or an empty state for a document with no pages.
struct ContentView: View {
    @Bindable var document: QuireDocument

    @State private var viewer = ViewerController()
    @State private var query = ""

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                PDFViewer(pdf: document.pdf, controller: viewer)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .onSubmit(of: .search) {
            viewer.submitSearch(query, in: document.pdf)
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                viewer.clearSearch()
            }
        }
        .toolbar {
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
