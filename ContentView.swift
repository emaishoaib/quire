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

    var body: some View {
        Group {
            if document.pdf.pageCount == 0 {
                ContentUnavailableView("No Pages", systemImage: "doc")
            } else {
                PDFViewer(pdf: document.pdf)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
