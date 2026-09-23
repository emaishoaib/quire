//
//  ContentView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import PDFKit
import SwiftUI

/// The window's contents.
///
/// A placeholder until the viewer lands: showing the page count proves the file was read.
struct ContentView: View {
    @Bindable var document: QuireDocument

    var body: some View {
        Text("\(document.pdf.pageCount) pages")
            .font(.title)
            .foregroundStyle(.secondary)
            .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
