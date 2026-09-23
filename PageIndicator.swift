//
//  PageIndicator.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/23/26.
//

import SwiftUI

/// The page number in the bottom-right of the Read view.
///
/// The number is a field: type a page and press Return to jump there. It follows the
/// document as you scroll, except while you are typing in it, so your half-entered
/// number is never overwritten underneath you.
struct PageIndicator: View {
    let viewer: ViewerController
    let pageCount: Int

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 3) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(width: fieldWidth)
                .focused($isFocused)
                .onSubmit(jump)

            Text("/ \(pageCount)")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .monospacedDigit()
        .padding(.horizontal, 6)
        .floatingCapsule()
        .fixedSize()
        .help("Current page. Type a number and press Return to go there.")
        .onAppear { showCurrentPage() }
        .onChange(of: viewer.currentPage) {
            guard !isFocused else { return }
            showCurrentPage()
        }
    }

    private var fieldWidth: Double {
        Double("\(pageCount)".count) * 10 + 10
    }

    private func showCurrentPage() {
        text = "\(viewer.currentPage + 1)"
    }

    private func jump() {
        if let page = Int(text.trimmingCharacters(in: .whitespaces)), (1...pageCount).contains(page) {
            viewer.goToPage(page - 1)
        }
        isFocused = false
        showCurrentPage()
    }
}
