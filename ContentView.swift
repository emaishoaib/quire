//
//  ContentView.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var document: QuireDocument
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        TextEditor(text: $document.text)
            .onChange(of: document.text) { oldValue, _ in
                undoManager?.registerUndo(withTarget: document) { document in
                    document.text = oldValue
                }
            }
            .font(.system(size: 16, weight: .regular, design: .monospaced))
    }
}

#Preview {
    ContentView(document: QuireDocument())
}
